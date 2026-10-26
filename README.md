# G-Helper for Dank Material Shell

Native DMS/QML controls with a small Rust bridge. All hardware operations use G-Helper Unified IPC (`$XDG_RUNTIME_DIR/ghelper.sock`); no direct sysfs writes or G-Helper core changes.

## Structure

- `RogControlWidget.qml`: DMS entry point and square bar logo area.
- `RogPanel.qml`: fixed-width panel layout and bindings.
- `RogIpc.qml`: serialized queue, capability gates, polling, mutation outcomes and connection state.
- `components/`: shared section headings, metric cards, segmented controls and theme-aware logo.
- `bridge/`: Rust transport; checks runtime ownership/permissions, Linux peer credentials, response ID/version and frame limits. Uses only `libc` and `serde_json`.
- `scripts/`: reproducible build/deployment; `tests/`: isolated socket and QML state tests.

## Build and deploy

Requires stable Rust/Cargo, a C linker, DMS >= 1.5.0 and running G-Helper with Unified IPC.

```sh
./scripts/build.sh
./scripts/deploy.sh
```

Deployment copies only this plugin's QML, SVG, manifest and compiled binary, then runs `dms restart`. The installed widget runs the compiled binary using a component-relative URL; Python and Cargo are not needed at runtime. Rebuild on the target architecture. `Cargo.lock` pins dependencies.

## Behavior

Monitoring runs every 3 seconds while the panel is open and every 30 seconds when closed. Battery reads are less frequent; capabilities refresh periodically and when opening the panel. Busy responses back off. Mutations take priority over queued reads, disable controls until completion and never retry automatically. A timeout does not undo a hardware operation; inspect readback before retrying.

GPU choices come from capabilities. Selection reflects configured GPU mode, while the current physical mode and reboot requirement remain visible. Battery observed and saved limits are separate; firmware normalization and full-charge override are displayed.

Display retains the same segment model across sensor polls and current-Hz changes; advertised-mode or control-availability changes update the options. It shows the observed current Hz at the far right of its section heading and uses equal-width Auto / advertised Hz segments. `display.auto.get` reads the native preference and `display.auto.set` sends a boolean `enabled`. G-Helper owns the AC/Battery policy and Overdrive; the plugin never implements a competing switching algorithm. Manual Hz changes re-read Auto even on failure, because the server may have disabled the preference before a failed modeset.

## Verification

```sh
cargo fmt --manifest-path bridge/Cargo.toml --check
cargo clippy --manifest-path bridge/Cargo.toml --all-targets -- -D warnings
python3 -m unittest discover -s tests -v
./tests/run-state-tests.sh
qmllint RogControlWidget.qml RogPanel.qml RogIpc.qml components/*.qml
```

Socket tests use private temporary mock servers. State tests hold the request runner busy and never touch hardware. Quickshell needs access to its runtime directory; restricted sandboxes may require running these tests outside the sandbox. QML lint checks parsing; actual DMS loading is also required to validate native imports.

See `VERIFICATION.md` for measured results and remaining limits.

## Logo

ROG Eye SVG from [Simple Icons](https://github.com/simple-icons/simple-icons), downloaded via `https://cdn.simpleicons.org/republicofgamers`. Monochrome variants preserve its geometry and viewBox. The mark belongs to its respective owner.

Auto requires `displayAuto:true` and both methods in capabilities. On older or unsupported backends the Auto segment is disabled and shows “Auto unsupported”; manual rates remain usable. Unknown, failed or malformed Auto reads never appear as a known Off state. Opening the popup requests fresh capabilities, monitoring and Auto state, including when another read is already in flight.
