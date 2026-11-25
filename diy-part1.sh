#!/bin/bash
#
# OpenWrt upstream main without TurboACC, with SONiC Fullcone integrated
# after feeds are installed by diy-part2.sh.
#
set -euo pipefail

INSTALLER_URL="https://raw.githubusercontent.com/mufeng05/turboacc/main/add_turboacc.sh"

curl -fsSL "${INSTALLER_URL}" -o /tmp/add_turboacc.sh
bash /tmp/add_turboacc.sh
