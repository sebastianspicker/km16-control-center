# KM16 Control Center

A macOS profile editor and action launcher for the MMD KM16 Pro macro pad.
Assign shortcuts, text, commands, and app actions to its 16 keys and three knobs.

<details>
<summary>Status and limitations</summary>

KM16 Control Center is an independent experimental project for editing
macro-pad profiles and launching desktop actions. Developed independently
alongside my main professional work. The app and portable firmware core
remain alpha starting points to review and adapt. The Mac app can edit
profiles and run actions, but live pad input, device configuration and
firmware flashing are not implemented; the C core is not a flashable image.

**Disclaimer.** Imported assignments can execute commands or affect other
applications. Review their contents and permissions before enabling live
actions, keep recoverable copies of important work, and take responsibility
for changes made on your Mac.

</details>

The app works without a pad connected. Profiles stay on the Mac; live pad
input, device configuration, and firmware flashing are not implemented. This
repository also contains the hardware research and a portable C firmware core.

Try the [browser demo](https://sebastianspicker.github.io/km16-control-center/)
with the same factory presets. All actions are simulated. See the
[demo guide](site/README.md) to run it locally or host your own copy.

The current workflow runs on the Mac; the physical pad is not connected to it.

```mermaid
flowchart LR
    A[Edit a profile] --> B[Save assignments on the Mac]
    B --> C[Preview an action]
    B --> D[Run Selected with live actions enabled]
    D --> E[Mac apps or configured services]
```

## Get started

Requires macOS 14 or newer with full Xcode 16 or newer installed (it provides Swift 6
and the macOS SDK; builds with only the Command Line Tools are not supported), and
Python 3.10 or newer. If `xcode-select -p` does not print a path inside `Xcode.app`,
run `sudo xcode-select -s /Applications/Xcode.app`. From the repository root:

```sh
bash script/build_and_run.sh
```

The script builds an optimized app at `build/apps/KM16ControlCenter.app` and opens it.
Add `--build-only` to build without launching. Close the app before rebuilding. This
is an ad-hoc signed, unnotarized development build; after a rebuild macOS may ask
for Accessibility permission again (see the [app guide](docs/app-guide.md#build-and-run)).

Choose a profile, select a key or knob, then use **Preview action** or
**Command-Return** to simulate its assignment. To execute an action, enable live
actions in **Connections** and use **Run Selected**. Desktop input requires macOS
Accessibility permission. Review imported assignments first: profiles can contain
commands, text, and agent prompts.

See the [app guide](docs/app-guide.md) for storage, import/export,
recovery, and optional OBS and Codex setup.

## Screenshot tour

These screenshots show the running app with factory profiles. Live actions are
disabled and optional services are not connected.

### Profile editor

Switch profiles in the sidebar and select any key, knob turn, or knob press to
inspect its action. The Desktop preset covers everyday editing, app launching,
media, and scrolling.

![Desktop workspace with the 16-key layout, three knobs, and Copy assignment inspector](docs/screenshots/workspace.jpg)

### Preset library

The library includes 16 presets and 400 assignments for development, writing,
meetings, creative work, and streaming. Adding missing presets preserves existing
edits. App-specific presets may need setup; the
[preset catalog](presets/README.md) lists the requirements.

![Preset Library with the Developer preset selected and its setup information visible](docs/screenshots/preset-library.jpg)

### Action inspector

Edit shortcuts, text, app destinations, and commands in the assignment inspector.
Personal Automations calls your own Apple Shortcuts by name; create those routines
in Shortcuts before running them. Preview shows what would run without starting it.

![Personal Automations profile with the Start Workday shortcut name and Preview action button](docs/screenshots/action-editor.jpg)

### Connections

Connections holds the live-action setting and optional integration setup. OBS uses
WebSocket v5, with its password kept in memory. Agent Deck connects to an installed
Codex CLI and a workspace you choose. Neither service is needed to edit profiles.

![Connections window with live actions disabled and unconfigured OBS audio sources](docs/screenshots/connections.jpg)

## Documentation and development

The source-build workflow runs automatically only for Dependabot-authored PRs
and can be dispatched manually. Publishing the browser demo requires a manual
workflow run on `main`; ordinary pushes and PRs do not deploy it.

| Guide | What you'll find |
| --- | --- |
| [App guide](docs/app-guide.md) | Profiles, desktop actions, OBS, Agent Deck, and recovery |
| [Preset catalog](presets/README.md) | Assignments and setup instructions for the included apps |
| [Browser demo](site/README.md) | Interactive mockup, local preview, and GitHub Pages setup |
| [Contributing](CONTRIBUTING.md) | Development requirements and build commands |
| [Architecture](docs/development/COMPANION-ARCHITECTURE.md) | Swift package boundaries and integration behavior |
| [Releasing](docs/RELEASING.md) | Source releases and Mac app distribution requirements |

The ad-hoc signed app bundle can be validated without a pad, OBS, Codex, or private
research files:

```sh
bash script/build_and_run.sh --build-only
```

## Hardware research

The research documents the examined KM16 Pro board and stock behavior. Findings
are tied to the recorded hardware and firmware revisions. The
[portable C core](firmware/custom/README.md) has a host demo; it is not a
flashable firmware image.

| Guide | Contents |
| --- | --- |
| [Board analysis](docs/analysis/LIVE-FIRMWARE-ANALYSIS.md) | Application readback, hardware findings, and acquisition limits |
| [Offline findings](docs/analysis/OFFLINE-FINDINGS.md) | Settings, protocol behavior, and recovered hardware contract |
| [Key and knob mapping](docs/analysis/KNOB-MAPPING.md) | Observed stock-layer assignments |
| [Reference-image analysis](docs/analysis/FIRMWARE-ANALYSIS.md) | A separate vendor image with unproven compatibility |
| [Mac research tools](docs/workflows/mac-tools.md) | Device snapshots, HID capture, WebHID logging, and offline analysis |

Vendor firmware, raw captures, and third-party reference files are excluded from
the repository. Reports retain hashes and artifact names for provenance.
Reproducing the research requires matching original inputs.

## License

Original code and documentation are [MIT licensed](LICENSE). The license does not
grant redistribution rights for vendor firmware or third-party material.
