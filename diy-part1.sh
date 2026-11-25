#!/bin/bash
#
# Official OpenWrt 25.12 + latest turboacc (fw4 compatibility mode)
#
set -euo pipefail

# Always use the latest installer from the upstream main branch.
INSTALLER_URL="https://raw.githubusercontent.com/mufeng05/turboacc/main/add_turboacc.sh"

curl -fsSL "${INSTALLER_URL}" -o /tmp/add_turboacc.sh
bash /tmp/add_turboacc.sh
