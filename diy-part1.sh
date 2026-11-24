#!/bin/bash
#
# OpenWrt upstream main + latest turboacc.
# This branch intentionally follows the moving turboacc default branch.
#
set -euo pipefail

INSTALLER_URL="https://raw.githubusercontent.com/mufeng05/turboacc/main/add_turboacc.sh"

curl -fsSL "${INSTALLER_URL}" -o /tmp/add_turboacc.sh
bash /tmp/add_turboacc.sh
