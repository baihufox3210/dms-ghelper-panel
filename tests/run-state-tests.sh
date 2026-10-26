#!/bin/sh
set -eu
project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
test_dir=$(mktemp -d /tmp/rog-qml-test.XXXXXX)
trap 'rm -rf "$test_dir"' EXIT HUP INT TERM
cp "$project_dir/RogIpc.qml" "$test_dir/RogIpc.qml"
sed 's|import ".." as Rog|import "." as Rog|' "$project_dir/tests/StateTests.qml" > "$test_dir/shell.qml"
QT_QPA_PLATFORM=offscreen quickshell -p "$test_dir/shell.qml" > "$test_dir/result.log" 2>&1
cat "$test_dir/result.log"
rg -q "ROG_STATE_TESTS_PASS" "$test_dir/result.log"
