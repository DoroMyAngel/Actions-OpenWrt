#!/bin/bash
#
# OpenWrt DIY script part 2 (After Update/Install feeds)
#
set -euo pipefail

# Install the TCP CCA service. LEDE stores the selection in firewall.defaults.tcpcca.
mkdir -p files/etc/init.d
cat > files/etc/init.d/tcp-cca <<'EOF'
#!/bin/sh /etc/rc.common
START=99
USE_PROCD=1

apply_tcp_cca() {
    local cca available
    cca="$(uci -q get firewall.@defaults[0].tcpcca)"
    [ -n "$cca" ] || cca="$(uci -q get firewall.@defaults[0].tcp_cca)"
    case "$cca" in
        bbr) modprobe tcp_bbr 2>/dev/null || true ;;
        cubic|"") cca="cubic" ;;
        reno) ;;
        *) logger -t tcp-cca "Unsupported algorithm '$cca'; falling back to CUBIC"; cca="cubic" ;;
    esac

    available=" $(cat /proc/sys/net/ipv4/tcp_available_congestion_control 2>/dev/null) "
    case "$available" in
        *" $cca "*) sysctl -q -w "net.ipv4.tcp_congestion_control=$cca" ;;
        *) logger -t tcp-cca "Algorithm '$cca' unavailable; falling back to CUBIC"; sysctl -q -w net.ipv4.tcp_congestion_control=cubic ;;
    esac
}

start_service() { apply_tcp_cca; }
reload_service() { apply_tcp_cca; }
service_triggers() { procd_add_reload_trigger firewall; }
EOF
chmod 0755 files/etc/init.d/tcp-cca
[ ! -f files/etc/uci-defaults/zz-tcp-cca ] || chmod 0755 files/etc/uci-defaults/zz-tcp-cca

# Apply SONiC Fullcone after feeds are installed (including the LuCI firewall feed).
SONIC_INSTALLER_URL="https://raw.githubusercontent.com/mufeng05/openwrt-sonic-fullcone/master/add_sonic_fullcone.sh"
curl -fsSL "${SONIC_INSTALLER_URL}" -o /tmp/add_sonic_fullcone.sh
bash /tmp/add_sonic_fullcone.sh

# Port LEDE's firewall controls and runtime status, while retaining SONiC's Fullcone UCI model.
python3 - <<'PY'
from pathlib import Path

js = Path("feeds/luci/applications/luci-app-firewall/htdocs/luci-static/resources/view/firewall/zones.js")
if not js.is_file():
    raise SystemExit(f"ERROR: missing LuCI firewall page: {js}")
data = js.read_text()

def once(source, old, new, label):
    count = source.count(old)
    if count != 1:
        raise SystemExit(f"ERROR: expected exactly one {label} anchor, found {count}")
    return source.replace(old, new, 1)

# Runtime status support, following LEDE's load/poll model.
data = once(data, "'require view';\n", "'require view';\n'require fs';\n'require poll';\n", "view imports")
data = once(data,
    "\tload() {\n\t\treturn Promise.all([\n\t\t\tthis.callConntrackHelpers(),\n\t\t\tfirewall.getDefaults()\n\t\t]);\n\t},",
    """\tgetRuntimeStatus() {
\t\treturn L.resolveDefault(
\t\t\tfs.exec_direct('/usr/libexec/luci-firewall-status', [], 'json'), {});
\t},

\tload() {
\t\treturn Promise.all([
\t\t\tthis.callConntrackHelpers(),
\t\t\tfirewall.getDefaults(),
\t\t\tthis.getRuntimeStatus()
\t\t]);
\t},""", "load()")
data = once(data,
    "\trenderZones([ctHelpers, fwDefaults]) {\n\t\tlet m, s, o, out;\n\t\tconst fw4 = L.hasSystemFeature('firewall4');",
    """\trenderZones([ctHelpers, fwDefaults, runtimeStatus]) {
\t\tlet m, s, o, out;
\t\tconst fw4 = L.hasSystemFeature('firewall4');
\t\tconst runtimeStatusText = E('span', {}, [ '-' ]);
\t\tconst updateRuntimeStatus = (status) => {
\t\t\tconst natModes = {
\t\t\t\tfullcone: _('SONiC Fullcone NAT'),
\t\t\t\tnat1: _('Broadcom Fullcone NAT1'),
\t\t\t\tdisabled: _('Disabled')
\t\t\t};
\t\t\tconst natMode = natModes[status?.nat_mode] || _('Unknown');
\t\t\tconst tcpcca = status?.tcp_cca ? status.tcp_cca.toUpperCase() : _('Unknown');
\t\t\truntimeStatusText.textContent =
\t\t\t\t_('Running status: %s, TCP congestion control algorithm is %s').format(natMode, tcpcca);
\t\t};
\t\tconst addTCPCCAOption = () => {
\t\t\tconst tcpcca = s.option(form.ListValue, 'tcpcca', _('TCP CCA'),
\t\t\t\t_('TCP congestion control algorithm.'));
\t\t\ttcpcca.value('bbr', 'bbr');
\t\t\ttcpcca.value('cubic', 'cubic');
\t\t\ttcpcca.value('reno', 'reno');
\t\t\ttcpcca.default = 'bbr';
\t\t\ttcpcca.rmempty = false;
\t\t\ttcpcca.cfgvalue = function(section_id) {
\t\t\t\tconst value = uci.get('firewall', section_id, 'tcpcca');
\t\t\t\treturn value != null ? value : uci.get('firewall', section_id, 'tcp_cca');
\t\t\t};
\t\t\ttcpcca.write = function(section_id, value) {
\t\t\t\tuci.unset('firewall', section_id, 'tcp_cca');
\t\t\t\tuci.set('firewall', section_id, 'tcpcca', value);
\t\t\t};
\t\t};

\t\tupdateRuntimeStatus(runtimeStatus);""", "renderZones signature")
# The SONiC installer inserts its own global gate and per-zone options. Keep those controls
# and add the LEDE TCP CCA selector independently of Fullcone support.
data = once(data, "\t\tlet p = [\n", "\t\taddTCPCCAOption();\n\n\t\tlet p = [\n", "TCP CCA placement")

flow_start = data.find("\t\t/* Netfilter flow offload support */")
flow_end = data.find("\n\n\t\ts = m.section(form.GridSection, 'zone', _('Zones'));", flow_start)
if flow_start < 0 or flow_end < 0:
    raise SystemExit("ERROR: cannot locate native flow-offloading section")
flow = """\t\t/* Netfilter flow offload support */

\t\tconst hasMediatekHNAT = fw4 && runtimeStatus?.hnat_available === true;
\t\tconst hasQualcommECM = runtimeStatus?.ecm_available === true;
\t\tif (L.hasSystemFeature('offloading') || hasMediatekHNAT || hasQualcommECM) {
\t\t\ts = m.section(form.TypedSection, 'defaults', _('Routing/NAT Offloading'),
\t\t\t\t_('Not fully compatible with QoS/SQM.'));

\t\t\ts.anonymous = true;
\t\t\ts.addremove = false;

\t\t\to = s.option(form.RichListValue, 'offloading_type', _('Flow offloading type'));
\t\t\to.value('0', _('None'));
\t\t\tif (L.hasSystemFeature('offloading'))
\t\t\t\to.value('1', _('Software flow offloading'), _('Software based offloading for routing/NAT.'));
\t\t\tif (L.hasSystemFeature('offloading_hw'))
\t\t\t\to.value('2', _('Hardware flow offloading'), _('Hardware based offloading for routing with/without NAT.') + ' ' + _('Requires hardware NAT support.'));
\t\t\tif (hasMediatekHNAT)
\t\t\t\to.value('3', _('MediaTek HNAT'), _('Hardware NAT offloading using the MediaTek vendor driver.'));
\t\t\tif (hasQualcommECM)
\t\t\t\to.value('4', _('Qualcomm NSS ECM acceleration'), _('Automatically select the acceleration engine in ECM Auto mode.'));
\t\t\to.optional = false;
\t\t\to.load = function(section_id) {
\t\t\t\tconst flow_offloading = uci.get('firewall', section_id, 'flow_offloading');
\t\t\t\tconst flow_offloading_hw = uci.get('firewall', section_id, 'flow_offloading_hw');
\t\t\t\tif (hasQualcommECM && uci.get('ecm', 'global', 'acceleration_engine') !== 'disabled')
\t\t\t\t\treturn '4';
\t\t\t\tif (hasMediatekHNAT && flow_offloading === '3')
\t\t\t\t\treturn '3';
\t\t\t\treturn (flow_offloading === '1' && L.hasSystemFeature('offloading'))
\t\t\t\t\t? ((flow_offloading_hw === '1' && L.hasSystemFeature('offloading_hw')) ? '2' : '1')
\t\t\t\t\t: '0';
\t\t\t};
\t\t\to.write = function(section_id, value) {
\t\t\t\tif (hasQualcommECM) {
\t\t\t\t\tif (!uci.get('ecm', 'global'))
\t\t\t\t\t\tuci.add('ecm', 'ecm', 'global');
\t\t\t\t\tuci.set('ecm', 'global', 'acceleration_engine', value === '4' ? 'auto' : 'disabled');
\t\t\t\t}
\t\t\t\tuci.set('firewall', section_id, 'flow_offloading', value === '3' ? '3' : ((value === '1' || value === '2') ? '1' : '0'));
\t\t\t\tuci.unset('firewall', section_id, 'mediatek_hnat');
\t\t\t\tuci.set('firewall', section_id, 'flow_offloading_hw',
\t\t\t\t\t(value === '2' && L.hasSystemFeature('offloading_hw')) ? '1' : null);
\t\t\t};

\t\t\tif (fw4 && L.hasSystemFeature('offloading_hw') && !L.hasSystemFeature('zte_npu')) {
\t\t\t\to = s.option(form.ListValue, 'flow_offloading_hw_ipv6', _('Hardware offloading protocols'));
\t\t\t\to.value('1', _('IPv4+v6 acceleration'));
\t\t\t\to.value('0', _('IPv4 acceleration'));
\t\t\t\to.default = '1';
\t\t\t\to.rmempty = false;
\t\t\t\to.retain = true;
\t\t\t\to.depends('offloading_type', '2');
\t\t\t}
\t\t}"""
data = data.slice(0, flow_start) + flow + data.slice(flow_end)

# Insert LEDE-style status panel and refresh it every five seconds.
data = once(data, "\t\treturn m.render();",
    """\t\treturn m.render().then(L.bind(function(mapEl) {
\t\t\tconst firstSection = mapEl.querySelector('.cbi-section');
\t\t\tconst statusSection = E('div', {
\t\t\t\t'class': 'cbi-section firewall-runtime-status',
\t\t\t\t'style': 'overflow-x:auto'
\t\t\t}, [
\t\t\t\tE('div', {
\t\t\t\t\t'style': 'padding:.75em 1.5em;color:#008000;font-size:1em;font-weight:600;white-space:nowrap'
\t\t\t\t}, [ runtimeStatusText ])
\t\t\t]);
\t\t\tif (firstSection && firstSection.parentNode)
\t\t\t\tfirstSection.parentNode.insertBefore(statusSection, firstSection);
\t\t\tpoll.add(L.bind(function() {
\t\t\t\treturn this.getRuntimeStatus().then(updateRuntimeStatus);
\t\t\t}, this), 5);
\t\t\treturn mapEl;
\t\t}, this));""", "map render return")
js.write_text(data)

# Install the LEDE-style runtime status helper, with SONiC fullcone detection.
status = Path("files/usr/libexec/luci-firewall-status")
status.parent.mkdir(parents=True, exist_ok=True)
status.write_text("""#!/bin/sh

tcp_cca="$(cat /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null)"
nat_mode="disabled"
hnat_available=false
[ -e /sys/kernel/debug/hnat/hook_toggle ] && hnat_available=true
ecm_available=false
[ -x /etc/init.d/qca-nss-ecm ] && [ -f /etc/config/ecm ] &&
    [ -f /usr/share/ucitrack/qca-nss-ecm.json ] && ecm_available=true
ppe_bind_rate_available=false

rules="$(iptables-save -t nat 2>/dev/null)"
if printf '%s\\\\n' "$rules" | grep -q -- '--mode fullcone'; then
    nat_mode="nat1"
elif printf '%s\\\\n' "$rules" | grep -q -- '-j FULLCONENAT'; then
    nat_mode="fullcone"
else
    rules="$(nft list ruleset 2>/dev/null)"
    if printf '%s\\\\n' "$rules" | grep -Eq 'masquerade[[:space:]]+fullcone'; then
        nat_mode="nat1"
    elif printf '%s\\\\n' "$rules" | grep -Eq '(^|[[:space:]])fullcone([[:space:]]|$)|fullcone[[:space:]]+to'; then
        # SONiC emits the nftables fullcone expression, not Broadcom NAT1.
        nat_mode="fullcone"
    fi
fi

printf '{"nat_mode":"%s","tcp_cca":"%s","hnat_available":%s,"ecm_available":%s,"ppe_bind_rate_available":%s}\\\\n' "$nat_mode" "$tcp_cca" "$hnat_available" "$ecm_available" "$ppe_bind_rate_available"
""")
status.chmod(0o755)

# Permit LuCI's authenticated RPC helper to execute the read-only status script.
acl = Path("feeds/luci/applications/luci-app-firewall/root/usr/share/rpcd/acl.d/luci-app-firewall.json")
if not acl.is_file():
    raise SystemExit(f"ERROR: missing LuCI firewall ACL: {acl}")
import json
acl_data = json.loads(acl.read_text())
read_files = acl_data.setdefault("luci-app-firewall", {}).setdefault("read", {}).setdefault("file", {})
read_files["/usr/libexec/luci-firewall-status"] = ["exec"]
acl.write_text(json.dumps(acl_data, indent="\\t") + "\\n")

po = Path("feeds/luci/applications/luci-app-firewall/po/zh_Hans/firewall.po")
if not po.is_file():
    raise SystemExit(f"ERROR: missing LuCI Chinese translation file: {po}")
text = po.read_text()
begin, end = "# BEGIN Actions-OpenWrt LEDE Firewall", "# END Actions-OpenWrt LEDE Firewall"
if begin in text and end in text:
    before, tail = text.split(begin, 1)
    _, after = tail.split(end, 1)
    text = before + after.lstrip("\\n")
entries = [
    ("TCP CCA", "TCP 拥塞控制算法"),
    ("TCP congestion control algorithm.", "TCP 拥塞控制算法。"),
    ("Running status: %s, TCP congestion control algorithm is %s", "运行状态：%s，TCP 拥塞控制算法为 %s"),
    ("SONiC Fullcone NAT", "SONiC 全锥形 NAT"),
    ("Broadcom Fullcone NAT1", "Broadcom Fullcone NAT1"),
    ("Disabled", "已禁用"),
    ("Unknown", "未知"),
    ("Routing/NAT Offloading", "路由/NAT 卸载"),
    ("Not fully compatible with QoS/SQM.", "与 QoS/SQM 不完全兼容。"),
    ("Flow offloading type", "流量卸载类型"),
    ("None", "无"),
    ("Software flow offloading", "软件流量卸载"),
    ("Software based offloading for routing/NAT.", "基于软件的路由/NAT 卸载。"),
    ("Hardware flow offloading", "硬件流量卸载"),
    ("Hardware based offloading for routing with/without NAT.", "使用硬件进行路由卸载，可支持或不支持 NAT。"),
    ("Requires hardware NAT support.", "需要硬件 NAT 支持。"),
    ("MediaTek HNAT", "MediaTek HNAT"),
    ("Hardware NAT offloading using the MediaTek vendor driver.", "使用 MediaTek 原厂驱动的硬件 NAT 卸载。"),
    ("Qualcomm NSS ECM acceleration", "Qualcomm NSS ECM 加速"),
    ("Automatically select the acceleration engine in ECM Auto mode.", "在 ECM Auto 模式下自动选择加速引擎。"),
    ("Hardware offloading protocols", "硬件加速协议"),
    ("IPv4+v6 acceleration", "IPv4+v6加速"),
    ("IPv4 acceleration", "IPv4加速"),
]
block = [begin]
for msgid, msgstr in entries:
    if ('msgid "' + msgid.replace('"', '\\"') + '"') in text:
        continue
    block += ['msgid "' + msgid.replace('"', '\\"') + '"',
              'msgstr "' + msgstr.replace('"', '\\"') + '"', '']
block.append(end)
text = text.rstrip() + "\n\n" + "\n".join(block) + "\n"
po.write_text(text)
print("Ported LEDE TCP CCA, flow offloading and runtime status; retained SONiC Fullcone UI.")
PY
