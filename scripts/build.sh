#!/bin/sh
set -eu
project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cargo build --locked --release --manifest-path "$project_dir/bridge/Cargo.toml"
install -Dm755 "$project_dir/bridge/target/release/rog-ipc-bridge" "$project_dir/bin/rog-ipc-bridge"
