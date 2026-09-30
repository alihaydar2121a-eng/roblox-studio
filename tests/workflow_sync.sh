#!/usr/bin/env bash
# End-to-end test of Sync-Ironfront.ps1 / Watch-Ironfront.ps1 against a local
# "GitHub" (bare repo). Needs pwsh and git; rojo on PATH for the serve test.
# Usage: PWSH=/path/to/pwsh tests/workflow_sync.sh
set -euo pipefail
PWSH=${PWSH:-pwsh}
command -v "$PWSH" >/dev/null || { echo "skip: pwsh not found"; exit 0; }
REPO=$(cd "$(dirname "$0")/.." && pwd)
BR=claude/upbeat-fermi-oodwi6
W=$(mktemp -d)
trap 'rm -rf "$W"' EXIT
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
pass=0; fail=0
check() { if grep -q "$2" "$W/out"; then echo "ok   $1"; pass=$((pass+1)); else echo "FAIL $1 (expected: $2)"; cat "$W/out"; fail=$((fail+1)); fi; }

# origin (bare) seeded with the working tree, plus Claude's clone and the user's clone
git init -q "$W/seed" && cp -r "$REPO"/{default.project.json,src,Sync-Ironfront.ps1,Watch-Ironfront.ps1,plugin.project.json,plugin} "$W/seed/" && mkdir -p "$W/seed/scripts" && cp -r "$REPO/scripts/windows" "$W/seed/scripts/"
git -C "$W/seed" checkout -q -b $BR && git -C "$W/seed" add -A && git -C "$W/seed" commit -qm seed
git clone -q --bare "$W/seed" "$W/origin.git"
git clone -q -b $BR "$W/origin.git" "$W/claude"
git clone -q -b $BR "$W/origin.git" "$W/user"
watch() { "$PWSH" -NoProfile -File "$W/user/Watch-Ironfront.ps1" -Once "$@" >"$W/out" 2>&1 || true; }
remote_commit() { echo "$2" >> "$W/claude/$1"; git -C "$W/claude" add -A; git -C "$W/claude" commit -qm "$3"; git -C "$W/claude" push -q origin $BR; }

watch;                                           check "up to date"            "Up to date"
remote_commit src/shared/Config/WeaponConfig.lua "-- change 1" "Tune weapons"
watch;                                           check "fast-forward update"   "Updated 1 commit"
check "report lists commit" "Tune weapons";      check "report code changes"   "reach Studio automatically"
grep -q -- "-- change 1" "$W/user/src/shared/Config/WeaponConfig.lua" && { echo "ok   file updated"; pass=$((pass+1)); } || { echo "FAIL file updated"; fail=$((fail+1)); }

echo "-- my edit" >> "$W/user/src/shared/Config/WeaponConfig.lua"
remote_commit src/shared/Config/WeaponConfig.lua "-- change 2" "Second tune"
watch;                                           check "conflicting edit skipped" "local edits AND incoming"
grep -q -- "-- my edit" "$W/user/src/shared/Config/WeaponConfig.lua" && { echo "ok   local edit preserved"; pass=$((pass+1)); } || { echo "FAIL local edit lost"; fail=$((fail+1)); }
git -C "$W/user" checkout -q -- src/shared/Config/WeaponConfig.lua

echo "-- unrelated" >> "$W/user/src/shared/Config/GearModels.lua"
watch;                                           check "non-overlapping edit still updates" "Updated 1 commit"
grep -q -- "-- unrelated" "$W/user/src/shared/Config/GearModels.lua" && { echo "ok   unrelated edit kept"; pass=$((pass+1)); } || { echo "FAIL unrelated edit lost"; fail=$((fail+1)); }
git -C "$W/user" checkout -q -- src/shared/Config/GearModels.lua

echo x > "$W/user/local.txt"; git -C "$W/user" add local.txt; git -C "$W/user" commit -qm local
remote_commit src/shared/Config/WeaponConfig.lua "-- change 3" "Third"
before=$(git -C "$W/user" rev-parse HEAD)
watch;                                           check "diverged not merged"   "both have new commits"
[ "$before" = "$(git -C "$W/user" rev-parse HEAD)" ] && { echo "ok   HEAD unchanged"; pass=$((pass+1)); } || { echo "FAIL HEAD moved"; fail=$((fail+1)); }
git -C "$W/user" reset -q --hard "origin/$BR"   # test cleanup only

git -C "$W/user" checkout -q -b other; echo y > "$W/user/dirty.txt"
watch;                                           check "wrong branch + dirty refuses" "will not switch branches"
rm "$W/user/dirty.txt"
watch;                                           check "wrong branch clean switches" "Switched to $BR"

if command -v rojo >/dev/null; then
  timeout 12 "$PWSH" -NoProfile -File "$W/user/Sync-Ironfront.ps1" -NoPlugin -Port 34999 >"$W/out" 2>&1 || true
  check "sync builds project"   "default.project.json builds"
  check "sync starts rojo"      "Rojo is starting"
  check "rojo listening"        "listening"
fi
echo "workflow: $pass passed, $fail failed"
[ $fail -eq 0 ]
