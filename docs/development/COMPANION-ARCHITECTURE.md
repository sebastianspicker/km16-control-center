# KM16 Control Center architecture

KM16 Control Center is a SwiftPM macOS app for software profiles and explicit
desktop/service actions. Profiles do not synchronize with device firmware layers.

## Package structure

The Swift package is at the repository root. Dependencies point downward only:
the app depends on everything, and Core depends on nothing in the package.

| Target | Location | Responsibility |
| --- | --- | --- |
| `KM16ControlCore` | `Sources/KM16ControlCore` | Control IDs, action and profile models, validation, schema migration, persistence, library editing rules (`ProfileLibrary`), grouping, and simulation. No AppKit or SwiftUI |
| `KM16Presets` | `presets/` | Factory preset definitions (`Catalog/`), the bundled setup guides (`setup/`), and the generated JSON exports |
| `KM16Integrations` | `Sources/KM16Integrations` | Side effects: desktop input, audio, windows, bounded processes, OBS, the Codex transport, and saved HID capture decoding |
| `KM16ProcessSupport` | `Sources/KM16ProcessSupport` | C bridge that spawns an owned process group with explicit file descriptors |
| `KM16ControlCenter` | `Sources/KM16ControlCenter` | SwiftUI app: scenes, the shared observable store, editors, settings, and AppKit bridges |

`ControlCenterStore` owns session state: the working document, undo and redo,
dirty tracking, status messages, selection, and foreground-app bookkeeping. It
delegates library rules such as naming, merge import, and profile-switch
resolution to `ProfileLibrary`, which receives factory presets as values rather
than depending on the catalog. Live actions are routed from the main window's Run
Selected command to the desktop runner, the OBS controller, or the Codex client.

Preset definitions are Swift. `presets/<id>.json` and `presets/all.json` are
generated from them and checked byte for byte by the tests; the browser demo
reads `all.json`. The app bundles `presets/setup/` unchanged, and Export Setup
Files copies that folder.

The app shares one store and its providers across windows. Connection panels reuse
those providers. Termination handles unsaved profiles and stops owned providers.

## Input and actions

The 25 input slots cover 16 keys and three actions per knob. Preview and saved-capture
replay resolve assignments in the selected profile and produce bounded simulation
events. Profile-switch actions change local state. Neither path calls a live provider.

Run Selected requires live actions to be enabled. Desktop input validates the
action, checks Accessibility access, focuses the target app, and posts input to
that process. Commands use an absolute executable and literal arguments. Output,
execution time, and child-process lifetime are bounded; unrelated parent file
descriptors are not inherited. The activity log omits raw snippets, command
arguments and output, and prompts.

OBS actions use a short-lived WebSocket v5 connection. The endpoint and source names
are saved locally; the password remains in memory. Protocol code checks authentication,
request correlation, and status before reporting an action as complete.

The stock HID decoder handles the captured composite interface `28e9:3145`.
Report 6 contains a modifier byte and a 240-bit usage bitmap; report 4 contains a
little-endian consumer usage. Edge tracking suppresses held reports. These mappings
are specific to the studied stock layer. Fn and two knob presses were not visible
in the captures. The app does not enumerate or open HID devices.

## Profiles and persistence

Profiles contain a UUID, name, preset origin, summary, app-matching rules, and one
binding per control. Schema 1 migrates to schema 2 in memory. Incomplete legacy
actions can be edited but must pass validation before saving.

Import supports replacement and two same-name merge policies. Importing never runs
an action or changes the live-action preference. The import sheet warns that a
profile may run any absolute executable as the current macOS user or send a custom
prompt to the selected Codex thread. Saves validate and atomically replace the
document, retain the previous valid revision as a backup, and make a separate
recovery copy of an invalid original.
Reads enforce the 8 MiB limit and reject nonregular files and final-component symlinks.
The library permits 128 profiles; undo history holds 100 revisions and activity 80 events.

Display order groups profiles by use. Foreground matching follows document order,
falls back to Desktop, and yields to a manual override. Selecting a software profile
does not change a layer on the device.

## Codex transport

Agent Deck uses the locally generated [CLI 0.154.0 protocol subset](codex-protocol-0.154.0.json).
It owns a stdio app-server process and completes initialization before requesting
models or threads. The installed CLI supplies authentication.

The client lists workspace threads, starts and resumes tasks, submits or steers
prompts, interrupts turns, and displays output, plans, and diffs. Each thread has
separate state; completed-turn tracking handles delayed responses.
Approval and question replies preserve request IDs and reject stale requests.
New threads request `workspace-write` sandboxing and `on-request` approvals; the UI
does not offer persistent permission grants. Resumed threads keep their existing
server-owned permissions, which may be broader. The app does not inspect or replace
their sandbox, approval policy, workspace, or enabled tools. Sending a message is
separate from the Run Selected opt-in.

The transport bounds frames, buffered input, pending requests, and request time.
Its ordered reader accepts fragmented JSON lines; a separate queue writes to the
child process. Completion and cancellation release request timers. Disconnect
invalidates the connection generation and fails outstanding requests.

## Verification

Each target has a Swift Testing target in `Tests/`: models, persistence, and
library rules (`KM16ControlCoreTests`); preset content, export parity, setup
files, and the demo's group list (`KM16PresetsTests`); parsers, protocol and
approval fixtures, and child processes (`KM16IntegrationsTests`); and store
behavior (`KM16ControlCenterTests`). See [Contributing](../../CONTRIBUTING.md)
for commands. UI, accessibility, live services, desktop input, and physical
devices need separate testing. See [development status](IMPLEMENTATION-LEDGER.md)
for outstanding work and [Releasing](../RELEASING.md) for distribution checks.
