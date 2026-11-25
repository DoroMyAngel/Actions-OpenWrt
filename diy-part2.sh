#!/bin/bash
#
# OpenWrt DIY script part 2 (After Update/Install feeds)
#
set -euo pipefail

if [ -f files/etc/uci-defaults/zz-tcp-cca ]; then
    chmod 0755 files/etc/uci-defaults/zz-tcp-cca
fi

# Remove TurboACC's BCM Fullcone stack but retain flow offloading, BBR and Shortcut-FE.
python3 - <<'PY'
from pathlib import Path
import re
import shutil

kernel_patch_names = {
    "982-add-bcm-fullconenat-support.patch",
    "983-add-bcm-fullconenat-to-nft.patch",
    "984-netfilter-reserve-unconfirmed-nat-tuples.patch",
    "985-netfilter-bcm-fullcone-reserve-expectation-early.patch",
}
for hack_dir in Path("target/linux/generic").glob("hack-*"):
    for name in kernel_patch_names:
        patch = hack_dir / name
        if patch.exists():
            patch.unlink()

for path in (
    Path("package/turboacc/fullconenat"),
    Path("package/turboacc/fullconenat-nft"),
):
    if path.exists():
        shutil.rmtree(path)

patch_dirs = (
    Path("package/network/config/firewall/patches"),
    Path("package/network/config/firewall4/patches"),
    Path("package/network/utils/iptables/patches"),
    Path("package/network/utils/nftables/patches"),
    Path("package/libs/libnftnl/patches"),
)
for directory in patch_dirs:
    if not directory.is_dir():
        continue
    for patch in directory.iterdir():
        if patch.is_file() and "fullcone" in patch.name.lower():
            patch.unlink()

hw_patch = Path(
    "package/network/config/firewall4/patches/"
    "100-firewall4-hw-offload-ipv4-only-and-vendor-hnat.patch"
)
if hw_patch.is_file():
    content = hw_patch.read_text()
    content, count = re.subn(
        r'^\+\s*fullcone:\s*\[\s*"int",\s*"0"\s*\],\n',
        "",
        content,
        flags=re.MULTILINE,
    )
    if count != 1:
        raise SystemExit("ERROR: expected exactly one TurboACC Fullcone parser line in firewall4 hardware-offload patch")
    hw_patch.write_text(content)

print("Removed TurboACC BCM Fullcone modules/patches; retained other TurboACC features.")
PY

SONIC_INSTALLER_URL="https://raw.githubusercontent.com/mufeng05/openwrt-sonic-fullcone/master/add_sonic_fullcone.sh"
curl -fsSL "${SONIC_INSTALLER_URL}" -o /tmp/add_sonic_fullcone.sh
bash /tmp/add_sonic_fullcone.sh

# Adapt the TurboACC page so its boolean switch controls SONiC's global gate
# and every currently masquerading zone. Keep TCP CCA and Flow Offloading.
python3 - <<'PY'
from pathlib import Path

js = Path("package/turboacc/luci-app-turboacc/htdocs/luci-static/resources/view/turboacc.js")
if not js.is_file():
    raise SystemExit(f"ERROR: TurboACC LuCI page not found: {js}")

content = js.read_text()
old = """\t\tif (features.hasXTFULLCONENAT || features.hasNFTFULLCONENAT) {
\t\t\to = s.option(form.ListValue, 'fullcone', _('Enable FullCone NAT'));
\t\t\to.value('0', _('Disable'));
\t\t\to.value('1', _('FULLCONENAT'));
\t\t\to.value('2', _('Broadcom Fullcone NAT1'));
\t\t\taddTCPCCAOption();
\t\t\tif (fw4)
\t\t\t\to = s.option(form.Flag, 'fullcone6', _('Enable FullCone NAT6'));
\t\t}
\t\telse {
\t\t\taddTCPCCAOption();
\t\t}
"""
new = """\t\to = s.option(form.Flag, 'fullcone', _('Enable SONiC FullCone NAT'),
\t\t\t_('Controls the SONiC Fullcone global switch and all masquerading zones.'));
\t\to.enabled = '1';
\t\to.disabled = '0';
\t\to.default = '0';
\t\to.rmempty = false;
\t\to.load = function(section_id) {
\t\t\treturn uci.get('firewall', section_id, 'fullcone') === '1' ? '1' : '0';
\t\t};
\t\to.write = function(section_id, value) {
\t\t\tconst enabled = value === '1' ? '1' : '0';
\t\t\tuci.set('firewall', section_id, 'fullcone', enabled);
\t\t\tconst zones = uci.sections('firewall', 'zone') || [];
\t\t\tfor (const zone of zones) {
\t\t\t\tif (zone.masq === '1' && zone['.name'])
\t\t\t\t\tuci.set('firewall', zone['.name'], 'fullcone', enabled);
\t\t\t}
\t\t};
\t\taddTCPCCAOption();
"""
if old not in content:
    raise SystemExit("ERROR: expected TurboACC Fullcone UI block not found")
js.write_text(content.replace(old,new,1))

defaults = Path("package/turboacc/luci-app-turboacc/root/etc/uci-defaults/turboacc")
if not defaults.is_file():
    raise SystemExit(f"ERROR: TurboACC uci-defaults file not found: {defaults}")

data = defaults.read_text()
old_module_block = """\tif [ -e "/lib/modules/$kernel_ver/xt_FULLCONENAT.ko" ] || [ -e "/lib/modules/$kernel_ver/nft_fullcone.ko" ]; then
\t\tuci -q set "firewall.@defaults[0].fullcone"="1"
\telse
\t\tuci -q set "firewall.@defaults[0].fullcone"="0"
\tfi

"""
if old_module_block not in data:
    raise SystemExit("ERROR: expected module-based TurboACC Fullcone defaults block not found")
data = data.replace(old_module_block,"",1)

marker = 'uci -q commit "turboacc"'
sync = """# SONiC Fullcone is integrated into nft_masq.ko, not a separate module.
# Preserve the previous default-on behavior and enable masquerading zones.
if [ -z "$(uci -q get "firewall.@defaults[0].fullcone")" ]; then
\tuci -q set "firewall.@defaults[0].fullcone"="1"
fi
if [ "$(uci -q get "firewall.@defaults[0].fullcone")" = "1" ]; then
\tuci -q show firewall | sed -n 's/^firewall\\.\\([^=]*\\)=zone$/\\1/p' | while IFS= read -r zone; do
\t\tif [ "$(uci -q get "firewall.$zone.masq")" = "1" ]; then
\t\t\tuci -q set "firewall.$zone.fullcone"="1"
\t\tfi
\tdone
fi

"""
if marker not in data:
    raise SystemExit("ERROR: TurboACC uci-defaults commit marker not found")
defaults.write_text(data.replace(marker,sync+marker,1))
print("Adapted TurboACC LuCI Fullcone toggle and first-boot defaults for SONiC.")
PY
