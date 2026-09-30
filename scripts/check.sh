#!/usr/bin/env bash
# Offline checks for OPERATION IRONFRONT.
#   1. Luau syntax for every source/test file
#   2. Unit tests (pure game logic + world planning/heightfield)
#   3. Full map-generation harness under Lune (real Roblox datatypes)
#   4. Weapon/gear/pose harness under Lune; Blender export verification if bpy exists
#   5. Rojo builds of the place and the Studio plugin
# Needs luau + luau-compile + rojo (+ lune for step 3) on PATH, or TOOLS_DIR.
set -euo pipefail
cd "$(dirname "$0")/.."
T="${TOOLS_DIR:+$TOOLS_DIR/}"

echo "== Luau syntax"
fail=0
while IFS= read -r f; do
	if ! "${T}luau-compile" --binary "$f" >/dev/null 2>/tmp/luau_err; then
		echo "Syntax error in $f"; cat /tmp/luau_err; fail=1
	fi
done < <(find src tests plugin -name '*.lua' -o -name '*.luau')
[ "$fail" = 0 ] || exit 1
echo "ok"

echo "== Unit tests: gameplay logic"
"${T}luau" tests/run.luau
echo "== Unit tests: world planning + heightfield"
"${T}luau" tests/world.luau

if command -v "${T}lune" >/dev/null 2>&1; then
	echo "== Map generation harness (Lune)"
	"${T}lune" run tests/harness.luau
	echo "== Weapon / gear / pose harness (Lune)"
	"${T}lune" run tests/assets.luau
else
	echo "== Map generation harness skipped (lune not installed)"
fi

if python3 -c "import bpy" >/dev/null 2>&1; then
	echo "== Blender export verification (re-import FBX/GLB)"
	python3 scripts/blender/verify_exports.py | tail -1
	echo "== Premium asset verification (re-import FBX/GLB against the manifests)"
	python3 scripts/blender/premium/verify_premium.py 2>/dev/null | grep -E "FAIL|failures"
else
	echo "== Blender export verification skipped (bpy not installed)"
fi

echo "== Rojo build"
mkdir -p build
"${T}rojo" build default.project.json -o build/OperationIronfront.rbxlx
"${T}rojo" build plugin.project.json -o build/IronfrontTools.rbxmx
echo "Built build/OperationIronfront.rbxlx and build/IronfrontTools.rbxmx"

# Windows sync scripts (Sync-/Watch-Ironfront.ps1) against a throwaway local remote.
PWSH_BIN=${PWSH:-$(command -v pwsh || true)}
if [ -n "$PWSH_BIN" ]; then
  echo "== Git + Rojo sync workflow (PowerShell)"
  PATH="${T%/}:$PATH" PWSH="$PWSH_BIN" tests/workflow_sync.sh | tail -1
else
  echo "== Git + Rojo sync workflow: skipped (pwsh not installed)"
fi
