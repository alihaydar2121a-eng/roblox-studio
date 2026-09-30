#!/usr/bin/env bash
# Offline checks: Luau syntax for every source file, unit tests, Rojo build.
# Requires `luau`, `luau-compile` and `rojo` on PATH (or TOOLS_DIR pointing at them).
set -euo pipefail
cd "$(dirname "$0")/.."
T="${TOOLS_DIR:+$TOOLS_DIR/}"

echo "== Luau syntax"
fail=0
while IFS= read -r f; do
	if ! "${T}luau-compile" --binary "$f" >/dev/null 2>/tmp/luau_err; then
		echo "Syntax error in $f"; cat /tmp/luau_err; fail=1
	fi
done < <(find src tests -name '*.lua' -o -name '*.luau')
[ "$fail" = 0 ] || exit 1
echo "ok"

echo "== Unit tests"
"${T}luau" tests/run.luau

echo "== Rojo build"
mkdir -p build
"${T}rojo" build default.project.json -o build/OperationIronfront.rbxlx
echo "Built build/OperationIronfront.rbxlx"
