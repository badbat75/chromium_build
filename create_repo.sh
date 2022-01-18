#!/bin/bash
set -e
CHROMIUM_URL="https://chromium.googlesource.com/chromium/src.git"
echo "Create repo"
[ ! -f .gclient ] && cat >.gclient <<EOF
solutions = [
  {
    "name": "src",
    "url": "${CHROMIUM_URL}",
    "managed": False,
    "custom_deps": {},
    "custom_vars": {},
  },
]
EOF
git -c core.deltaBaseCacheLimit=2g clone --no-checkout --progress ${CHROMIUM_URL} src
echo
set +e