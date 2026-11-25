#!/bin/bash
#
# OpenWrt DIY script part 2 (After Update/Install feeds)
#
set -euo pipefail

# Install a small procd service that applies the selected local TCP CCA and
# re-applies it whenever the firewall UCI configuration changes.
mkdir -p files/etc/init.d
cat > files/etc/init.d/tcp-cca <<'EOF'
#!/bin/sh /etc/rc.common
START=99
USE_PROCD=1

apply_tcp_cca() {
    local cca available
    cca="$(uci -q get firewall.@defaults[0].tcp_cca)"
    case "$cca" in
        bbr) modprobe tcp_bbr 2>/dev/null || true ;;
        cubic|"") cca="cubic" ;;
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
[ ! -f files/etc/init.d/tcp-cca ] || chmod 0755 files/etc/init.d/tcp-cca

# Apply SONiC Fullcone after feeds are installed (including the LuCI firewall feed).
SONIC_INSTALLER_URL="https://raw.githubusercontent.com/mufeng05/openwrt-sonic-fullcone/master/add_sonic_fullcone.sh"
curl -fsSL "${SONIC_INSTALLER_URL}" -o /tmp/add_sonic_fullcone.sh
bash /tmp/add_sonic_fullcone.sh

# Add a TCP congestion-control selector to LuCI Firewall > General Settings.
python3 - <<'PY'
from pathlib import Path

js = Path("feeds/luci/applications/luci-app-firewall/htdocs/luci-static/resources/view/firewall/zones.js")
if not js.is_file():
    raise SystemExit(f"ERROR: missing LuCI firewall page: {js}")
data = js.read_text()
anchor = "\t\to = s.option(form.Flag, 'drop_invalid', _('Drop invalid packets'));\n"
addition = """\t\to = s.option(form.ListValue, 'tcp_cca', _('TCP congestion control'),
\t\t\t_('Algorithm for TCP connections initiated by this router; forwarded client connections are unaffected.'));
\t\to.value('cubic', _('CUBIC'));
\t\to.value('bbr', _('BBR'));
\t\to.default = 'bbr';
\t\to.rmempty = false;
"""
if data.count(anchor) != 1:
    raise SystemExit("ERROR: expected one TCP CCA insertion point in firewall zones.js")
if "'tcp_cca'" in data:
    raise SystemExit("ERROR: TCP CCA selector already exists")
js.write_text(data.replace(anchor, anchor + "\n" + addition, 1))

po = Path("feeds/luci/applications/luci-app-firewall/po/zh_Hans/firewall.po")
if not po.is_file():
    raise SystemExit(f"ERROR: missing LuCI Chinese translation file: {po}")
data = po.read_text()
begin, end = "# BEGIN Actions-OpenWrt TCP CCA", "# END Actions-OpenWrt TCP CCA"
if begin in data and end in data:
    before, tail = data.split(begin, 1)
    _, after = tail.split(end, 1)
    data = before + after.lstrip("\n")
block = '''# BEGIN Actions-OpenWrt TCP CCA
msgid "TCP congestion control"
msgstr "TCP 拥塞控制算法"

msgid "Algorithm for TCP connections initiated by this router; forwarded client connections are unaffected."
msgstr "设置本路由器自身发起的 TCP 连接所使用的算法，不影响经路由器转发的客户端连接。"

msgid "CUBIC"
msgstr "CUBIC"

msgid "BBR"
msgstr "BBR"
# END Actions-OpenWrt TCP CCA
'''
po.write_text(data.rstrip() + "\n\n" + block)
print("Added native Firewall TCP congestion-control selector.")
PY
