# Verification — 2026-10-26

## Completed

- Stable Rust 1.99.1 / Cargo 1.99.1: release build passed. Installed runtime binary is approximately 407 KiB; this is a size measurement, not a CPU benchmark.
- `cargo fmt --check` and Clippy with warnings denied passed.
- QML parsing with `qmllint` passed. The running DMS also loaded the plugin successfully after `dms restart`.
- Seven mock-socket test methods passed, including six mutation outcomes in subtests: fragmented responses, request shape, outcome preservation, protocol errors, mismatched IDs, incomplete frames, invalid parameters and unsafe runtime permissions. Mock tests never touch hardware.
- Forty-four QML state assertions passed: connection, unsupported methods, disabled/loading controls, duplicate requests, reboot, pending, blocked, poll/error persistence, battery observed values, failed outcomes, busy backoff, disconnect and malformed JSON.
- Actual DMS panel opened through native widget IPC. Dark and light theme screenshots inspected: square logo areas, monochrome logo variants, title hierarchy, symmetric margins, equal-width cards/buttons, no observed clipping. Original dark theme restored.
- A full DMS restart was necessary: plugin hot reload retained cached dependent QML types. Restarted and verified the new `ROG` / `Control center` header, rather than relying on the reload success message.
- DMS logs contained no ROG QML errors. Existing UPower PowerProfiles and portal registration warnings were present and are outside this plugin.

## Hardware IPC tests

All tests went through the compiled Rust bridge and existing Unified IPC. Each changed setting was restored immediately afterward.

| Control | Tested | Result / final setting |
|---|---|---|
| Monitoring | CPU/GPU temperatures and all three fans | Real readings received; null handling separately tested |
| Performance | Silent → Turbo → Balanced | `completed`; final readback Balanced. Does not prove every asynchronous tuning write |
| Refresh rate | 240 → 60 → 240 Hz | Both changes `applied`, matching readback |
| Brightness | 40 → 44 → 40% | Both calls `completed`, matching observed values |
| Battery limit | 100 → 80 → 100% | Both changes `applied`, saved and observed values match |
| GPU | Request currently active Ultimate | `already_set`; no cross-mode switch or reboot performed |

Button/slider handlers were reviewed against the IPC schema. The slider sends once at drag completion; its readback synchronization avoids resetting the new value before DMS emits the release signal. Physical mouse/keyboard interaction on every control has not been automated.

## Remaining limits

- Cross-mode GPU/MUX transitions, driver-blocking on real hardware, and post-reboot completion were not tested. Failure/pending/reboot UI state logic was tested with mocks.
- No plug/unplug battery event or full-charge override was triggered on real hardware.
- The battery branch of native Auto and Panel Overdrive hardware writes have not been independently verified. Auto uses the official IPC and G-Helper policy; no configuration-file writes or core modifications were made.
- Native light/dark screenshots were inspected on the current display only; other screen sizes, scaling factors and vertical-bar placement were not visually tested.
- No CPU-performance benchmark or runtime speedup claim is made for the Rust rewrite.

## Native Auto API update

Latest source and running `capabilities.get` now expose `displayAuto:true` and both native Auto methods. Verified `docs/IPC.md`, `GHelperIpcControls.Display.cs` and `IpcCommandRouter.cs` before wiring fields `enabled`, `onAc`, `currentHz`, and mutation `state`.

- UI: Auto is an equal-width segment beside 60 Hz / 240 Hz, with observed current Hz and the AC-highest / Battery-prefer-60 rule below. No separate switch/card. Header uses a square ROG logo, a single-line G-Helper title and a compact connection badge.
- Reads: capabilities gate both methods and backend availability; Auto status refreshes on popup opening and polling. Opening during another request schedules a full refresh after it drains.
- Mutations: Auto sends `display.auto.set {"enabled":true}`; choosing a manual rate uses `display.set`. After either request, Auto state is re-read before the regular monitoring reconciliation, including failed manual modesets.
- Failed Auto apply: retain the server's saved `enabled` preference and show an error rather than success. Missing/malformed outcomes, unknown methods and unsupported capabilities never produce an enabled control.
- Actual hardware: initial Auto=true, AC=true, 240 Hz. Auto Off returned applied and preserved 240 Hz; manual 60 Hz applied with Auto=false; Auto On applied and returned 240 Hz; manually selecting the already-current 240 Hz disabled Auto. Restored original Auto=true / AC / 240 Hz.
- No direct compositor display commands, G-Helper config access, core changes or backup files were used.

## Panel simplification

Removed the brightness label, value, slider and its QML IPC handler at the user's request. The historical brightness IPC test above remains a record of the bridge verification; the current panel no longer sends brightness changes. QML parsing passed after removal.

Moved observed current Hz to the far right of the Display heading. Shared `RogSection.valueText` keeps the heading and value vertically aligned, while sections without a value retain their existing appearance. Auto policy and status text remain beneath the segments. QML parsing passed.

Optimized Display model updates: monitoring retains the existing options array when advertised rates are unchanged (including differently ordered replies), preserving segment delegates and hover/focus state during sensor/current-Hz updates. Added assertions for model identity, selection updates and actual mode-list changes.
