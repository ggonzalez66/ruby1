#!/usr/bin/env bash
# Corre todas las pruebas de integración headless (y las de las herramientas en Python) y resume el resultado de cada una.
# Uso (desde cualquier carpeta): tests/run_tests.sh
set -u
cd "$(dirname "$0")/.."
status=0
for test in tests/integration/test_*.gd; do
	result=$(timeout 600 godot --headless --path . -s "res://$test" 2>&1 | grep -E "FAIL|RESULTADO|SCRIPT ERROR")
	echo "== $test"
	echo "$result"
	if ! echo "$result" | grep -q "RESULTADO" || echo "$result" | grep -qE "FAIL|SCRIPT ERROR"; then
		status=1
	fi
done
for test in tests/tools/test_*.py; do
	result=$(python3 "$test" 2>&1 | grep -E "FAIL|RESULTADO|Traceback")
	echo "== $test"
	echo "$result"
	if ! echo "$result" | grep -q "RESULTADO" || echo "$result" | grep -qE "FAIL|Traceback"; then
		status=1
	fi
done
exit $status
