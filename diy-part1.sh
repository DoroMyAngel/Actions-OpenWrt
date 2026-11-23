#!/bin/bash
#
# Official OpenWrt 25.12.6 + turboacc Full Cone (fw4 compatibility mode)
# turboacc source is pinned to a reviewed commit for reproducible builds.
#
set -euo pipefail

TURBOACC_COMMIT="ae412f5dffb2199bdd6c0a02a7bcba31ae0e544e"
INSTALLER_URL="https://raw.githubusercontent.com/mufeng05/turboacc/${TURBOACC_COMMIT}/add_turboacc.sh"

curl -fsSL "${INSTALLER_URL}" -o /tmp/add_turboacc.sh

# The upstream installer clones the moving main branch internally.
# Pin that clone to the exact commit used for this build.
sed -i 's@^git clone --depth=1 --single-branch https://github.com/mufeng05/turboacc "\$TMPDIR/turboacc" || exit 1$@git clone --depth=1 https://github.com/mufeng05/turboacc "\$TMPDIR/turboacc" || exit 1\n git -C "\$TMPDIR/turboacc" checkout ${TURBOACC_COMMIT} || exit 1@' /tmp/add_turboacc.sh

bash /tmp/add_turboacc.sh
