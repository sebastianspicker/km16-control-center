# KM16 Control Center

KM16 Control Center is a native macOS app for editing and previewing KM16 software
profiles. It can also run desktop actions, control OBS Studio, and connect to a
local Codex CLI app-server.

The app is host-only. It does not detect the keyboard, read or change its live configuration, suppress its stock input, or flash firmware.

## Requirements

Building from source requires a Mac running macOS 14 or later, a Swift 6 toolchain,
and Python 3.10 or later. The repository's full verification also uses Node.js,
CMake, and the Apple SDK; see [CONTRIBUTING.md](../../CONTRIBUTING.md).

Editing and previewing need no special permissions. Other features are opt-in:

- Desktop keyboard, text, scrolling, media, and window actions require
  Accessibility permission.
- OBS actions require OBS Studio with OBS WebSocket v5 enabled.
- Agent Deck requires a trusted Codex CLI executable. The checked-in protocol
  contract was generated from Codex CLI 0.154.0.

## Build and run

From the repository root:

```sh
bash script/build_and_run.sh
```

The script builds the unsigned development app at `build/apps/KM16ControlCenter.app` and opens it. To build without opening it, run:

```sh
bash script/build_and_run.sh --build-only
```

To test with a separate profile library, set `KM16_PROFILES_PATH` to the absolute
path of a `profiles.json` file before launching.

See [CONTRIBUTING.md](../../CONTRIBUTING.md) for development checks and focused test commands.

## Profiles

The factory library contains 16 profiles and 400 assignments. Each profile maps 16 keys and the clockwise, counterclockwise, and press inputs of three knobs. See the [preset library](../../presets/README.md) for every assignment and any required app setup.

Select a profile and control to edit its assignment. Preview or Command-Return simulates the selected action. Run Selected or Command-Shift-Return runs it after live actions are enabled. Profile-switch actions change the active software profile in either mode.

The sidebar can create, duplicate, rename, delete, and restore profiles. Imports use an explicit replace or merge policy; exports produce validated JSON. Undo and Redo cover library changes. Automatic matching selects the first profile that names the foreground app's bundle identifier and otherwise uses Desktop. Choosing a profile manually pauses automatic matching until you select Use Automatic Matching or Resume automatic matching.

These profiles stay on the Mac. Editing or selecting one does not change a firmware layer.

Imported profiles are executable configuration. They may insert text, run any
absolute executable as your macOS user, or send a custom prompt to the selected
Codex thread. Importing does not run anything or change the live-action setting.
Before using Run Selected, inspect unfamiliar assignments, including their target
app, executable, arguments, working directory, and prompt.

## Desktop actions

Desktop actions run locally after you enable live actions. Depending on the assignment, KM16 Control Center can:

- resolve shortcuts against the active ASCII-capable keyboard layout, focus the target app, verify that focus, and send the input;
- insert Unicode text without changing the clipboard;
- launch an installed app by bundle identifier;
- run an executable at an absolute path with a literal argument list;
- control system volume, mute, media playback, and scrolling; and
- move, resize, minimize, or focus a standard macOS window through Accessibility.

Process actions do not use shell parsing unless you explicitly choose a shell executable. They have bounded output and a timeout. Missing permissions or apps, rejected window operations, invalid action data, and nonzero process exits appear as errors.

The activity view omits raw snippets, process arguments and output, and Agent Deck prompts. Dictation is only a user-configured keyboard shortcut; the app neither chooses a Dictation binding nor records audio.

## OBS Studio

The Recording & Streaming preset uses OBS WebSocket v5. In Connections, enter a `ws://` or `wss://` endpoint, the WebSocket password, and the exact OBS input names for microphone and playback audio. The endpoint and input names are saved in preferences. The password stays in memory only for the current app process.

Each action uses a short-lived connection. Scene controls select the current Program scene. In Studio Mode, Transition sends the current Preview scene to Program. Volume steps change the linear multiplier by 0.05 and keep it between 0 and 1. Save Replay requires an active replay buffer.

Plain `ws://` connections are accepted only for localhost and loopback IP addresses. Remote OBS endpoints require `wss://` with a trusted TLS certificate. Redirects are refused to keep authentication bound to the configured endpoint.

The preset does not start a stream or create scenes, inputs, recording paths, or credentials. See the [Recording & Streaming setup guide](../../presets/setup/recording-streaming.md) before using it live.

## Agent Deck and Codex

In Connections, choose a trusted Codex executable and an existing workspace.
Authentication comes from the CLI's existing configuration. KM16 Control Center
starts its own local stdio app-server process; it does not attach to a Codex
Desktop window.

The default executable path, `/opt/homebrew/bin/codex`, is the usual Apple Silicon
Homebrew location. Run `command -v codex` in Terminal and enter the returned
absolute path in **Codex command** if your installation is elsewhere. Homebrew is
not required; the selected executable must support the app-server protocol.

Agent Deck loads models and workspace threads, starts or resumes threads, sends and
steers prompts, interrupts turns, displays output and plans, opens changed files
and diffs, and answers supported approval or input requests. Model and reasoning
options come from the connected server. An approval applies only to the request
shown on its card.

New threads request `workspace-write` sandboxing and `on-request` approvals.
Resumed threads keep their existing Codex permissions, which may be broader; the
app does not inspect or replace them. Check a resumed thread's workspace, sandbox,
approval policy, and tools before sending a prompt. This action does not depend on
the Run Selected toggle.

Approval cards show the request and matching operation details. Accept is available
only for the selected thread with complete, current evidence up to 16 KiB. The app
rejects stale or incomplete evidence, unknown fields, stdin requests without their
input bytes, and session-wide file-access grants. Decline and Cancel remain
available when the server supports them.

The client follows the generated [Codex CLI 0.154.0 protocol contract](../../docs/development/codex-protocol-0.154.0.json). Test other CLI versions before relying on them.

## Preset setup files

Preset Library shows all factory profiles and their setup guides. Add Missing Presets adds absent factory profiles without replacing existing ones. This is one undoable edit and remains unsaved until you select Save.

Export Setup Files… copies the guides and the additive Visual Studio Code keybindings fragment into a new folder. It does not install apps, change their settings, or replace VS Code's `keybindings.json`. Personal Automations calls Apple Shortcuts by exact name; create and review those shortcuts before running them.

## Storage and recovery

By default, profiles are stored at:

```text
~/Library/Application Support/KM16ControlCenter/profiles.json
```

Schema 1 files load as schema 2 in memory and remain unchanged until you save. Saving validates the document and replaces it atomically. A valid previous version becomes `profiles.json.backup`. Before replacing an invalid, unknown, or oversized file, the app writes a durable `profiles.json.recovery-<timestamp>-<uuid>.json` copy beside it.

Profile documents are limited to 128 profiles and 8 MiB. Undo retains up to 100 revisions, and the activity list retains up to 80 entries.

## Saved-capture replay

Replay Saved Capture reads a selected `composite.jsonl` file and feeds recognized controls into simulation. It never opens a HID device or sends desktop input. The decoder supports the captured stock report forms documented by this project; the available capture format does not expose every physical control.
