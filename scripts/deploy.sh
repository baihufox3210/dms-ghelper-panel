#!/bin/sh
set -eu
project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
plugin_dir="${XDG_CONFIG_HOME:-$HOME/.config}/DankMaterialShell/plugins/rogControl"
"$project_dir/scripts/build.sh"
install -d "$plugin_dir/components" "$plugin_dir/assets" "$plugin_dir/bin"
for name in RogControlWidget.qml RogPanel.qml RogIpc.qml plugin.json; do
    install -m644 "$project_dir/$name" "$plugin_dir/$name"
done
for name in "$project_dir"/components/*.qml; do install -m644 "$name" "$plugin_dir/components/"; done
for name in "$project_dir"/assets/*.svg; do install -m644 "$name" "$plugin_dir/assets/"; done
install -m755 "$project_dir/bin/rog-ipc-bridge" "$plugin_dir/bin/rog-ipc-bridge"
dms restart
