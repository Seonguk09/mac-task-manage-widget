#!/bin/sh
# CHANGELOG.md 에서 해당 버전 섹션 본문만 출력한다. 사용: scripts/release-notes.sh 1.12.1
v="$1"
[ -n "$v" ] || { echo "usage: $0 <version>" >&2; exit 2; }
awk -v v="$v" '
  /^## / { if (found) exit; split($0, a, " "); if (a[2] == v) { found = 1; next } }
  found { print }
' "$(dirname "$0")/../CHANGELOG.md" | sed -e '/./,$!d'
