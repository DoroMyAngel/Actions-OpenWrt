#!/bin/bash
#
# OpenWrt upstream main + latest turboacc.
# This branch intentionally follows the moving turboacc default branch.
#
set -euo pipefail

INSTALLER_URL="https://raw.githubusercontent.com/mufeng05/turboacc/main/add_turboacc.sh"

curl -fsSL "${INSTALLER_URL}" -o /tmp/add_turboacc.sh
bash /tmp/add_turboacc.sh

# Rebase TurboACC's Fullcone defaults hunk for current OpenWrt firewall4.
# OpenWrt removed the old disable_ipv6 comment lines; also disable HW offload
# on this x86_64 target while keeping software flow offloading enabled.
python3 - <<'PY'
from pathlib import Path
import re

patch = Path("package/network/config/firewall4/patches/001-firewall4-add-support-for-fullcone-nat.patch")
if not patch.is_file():
    raise SystemExit(f"ERROR: expected Fullcone patch not found: {patch}")

content = patch.read_text()
pattern = re.compile(
    r"(?ms)^--- a/root/etc/config/firewall\n"
    r"\\+\\+\\+ b/root/etc/config/firewall\n"
    r"@@ .*?^--- a/root/usr/share/firewall4/templates/ruleset\\.uc\n"
)
replacement = (
    "--- a/root/etc/config/firewall\n"
    "+++ b/root/etc/config/firewall\n"
    "@@ -5,1 +5,5 @@\n"
    " \\toption forward\\t\\tREJECT\n"
    "+\\toption flow_offloading\\t1\n"
    "+\\toption flow_offloading_hw\\t0\n"
    "+\\toption fullcone\\t\\t1\n"
    "+\\toption fullcone6\\t0\n"
    "--- a/root/usr/share/firewall4/templates/ruleset.uc\n"
)
updated, count = pattern.subn(lambda _: replacement, content, count=1)
if count != 1:
    raise SystemExit("ERROR: could not locate the expected firewall4 defaults hunk; refusing to continue")

patch.write_text(updated)
if "option flow_offloading_hw\t0" not in updated:
    raise SystemExit("ERROR: hardware flow offloading is not disabled in the rebased patch")
print("Rebased Fullcone firewall4 patch; software offloading=1, hardware offloading=0.")
PY
