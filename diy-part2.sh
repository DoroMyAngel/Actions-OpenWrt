#!/bin/bash
#
# OpenWrt DIY script part 2 (After Update feeds)
#
set -euo pipefail

# uci-defaults scripts must be executable in the final root filesystem.
if [ -f files/etc/uci-defaults/99-tcp-cca ]; then
    chmod 0755 files/etc/uci-defaults/99-tcp-cca
fi
