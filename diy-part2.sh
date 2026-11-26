#!/bin/bash
#
# OpenWrt DIY script part 2 (After Update/Install feeds)
#
# Keep the official OpenWrt firewall/LuCI implementation intact and apply
# only the SONiC Fullcone patches maintained by openwrt-sonic-fullcone.
#
set -euo pipefail

# Apply SONiC Fullcone patches after the official feeds are installed.
SONIC_INSTALLER_URL="https://raw.githubusercontent.com/mufeng05/openwrt-sonic-fullcone/master/add_sonic_fullcone.sh"
curl -fsSL "$SONIC_INSTALLER_URL" -o /tmp/add_sonic_fullcone.sh
bash /tmp/add_sonic_fullcone.sh

# Keep the first-boot defaults script executable in the firmware overlay.
chmod 0755 files/etc/uci-defaults/zz-sonic-fullcone

# Fail early if the SONiC firewall4/LuCI patches were not applied.
test -f package/network/config/firewall4/patches/001-sonic-fullcone.patch
test -f feeds/luci/applications/luci-app-firewall/patches/001-add-fullcone-options.patch

echo "Applied SONiC Fullcone patches; retained upstream OpenWrt firewall and LuCI controls."
