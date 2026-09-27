# Contributing

Describe the behavior you changed and the checks you ran in your pull request.

## Development checks

Use macOS 14 or newer, full Xcode with a Swift 6 toolchain, Python 3.10 or newer,
Node.js with `node --test`, and CMake 3.16 or newer. Xcode supplies the Apple SDK,
`xcrun clang`, and Swift used by the checks. The Python tools use only the standard
library. GitHub Actions runs the checks on a `macos-15` runner.

From the project root:

```sh
bash scripts/verify-source.sh
```

This compiles the HID capture utility with `xcrun clang`; runs the Node and Python
tests; configures, builds, and tests the portable C core with CMake and CTest; runs
the companion self-tests and preset asset checks; and finishes with the Swift
package tests. It uses synthetic fixtures without device access, desktop input,
OBS, or a real Codex session. Process tests launch and terminate local synthetic
fixtures and check a child-process heartbeat to verify cancellation.

CI also validates the documented unsigned app-bundle build without launching it:

```sh
bash script/build_and_run.sh --build-only
```

This creates `build/apps/KM16ControlCenter.app` and checks its `Info.plist`. It does
not sign, notarize, package, launch, or exercise live integrations.

Before building, CI checks that no tracked file also matches the repository's
ignore rules. This command must print nothing:

```sh
git ls-files --cached --ignored --exclude-standard
```

For focused checks:

```sh
bash scripts/verify-companion.sh
swift test --package-path apps/KM16ControlCenter
python3 -m unittest discover -s scripts/tests -p 'test_*.py' -v
node --test scripts/tests/webhid-trace.test.cjs
```

To measure Agent Deck's text-update path with a fixed 280 KB diff and a mock
transport, run:

```sh
swift run --package-path apps/KM16ControlCenter KM16IntegrationSelfTest --benchmark-deck
```

The benchmark checks the resulting transcript and changed-file list, then reports
seven timings after one warmup. Compare runs built with the same configuration.

See the [firmware guide](firmware/custom/README.md) for C builds and the
[app architecture](docs/development/COMPANION-ARCHITECTURE.md) for package boundaries.

The app icon source is `apps/KM16ControlCenter/Assets/AppIcon.png`. After changing
it, run `bash script/build_app_icon.sh` to regenerate the bundled `.icns` file.

The [browser demo](site/README.md) is a static HTML/CSS/JavaScript mockup. The source
checks validate its JavaScript syntax and build an allowlisted Pages artifact.
After UI changes, also check its interactions and desktop and narrow layouts in a
browser. Factory preset data comes from `presets/all.json` at build time.

## Compatibility and presets

Preserve profile IDs, schema migration, validation errors, and capture formats
unless a change is deliberate and documented. Preview and replay must remain
separate from actions that affect other apps or devices. Test observable behavior.

Edit setup guides in `presets/setup/` and make the same change in
`apps/KM16ControlCenter/Sources/KM16ControlCenter/Resources/PresetSetup/`.
Preset definition changes also need matching individual JSON exports and
`presets/all.json`. Check the assets with:

```sh
python3 scripts/verify-preset-assets.py
```

## Research contributions

Keep raw firmware, device captures, credentials, signing files, private logs, and
third-party material out of Git and GitHub issues. Use small synthetic fixtures for
public tests and remove personal data from logs and screenshots.

If you have the original research artifacts, `bash scripts/verify-offline.sh`
checks their hashes and reruns the pinned analyses. Those artifacts are not part
of a public checkout. See the [Mac research tools](docs/workflows/mac-tools.md) for
capture instructions.

Hardware reports should identify the device revision, connection mode, and method,
and distinguish physical observations from code analysis. Remove personal data
from logs before sharing them.

Contributions to this repository use the [MIT license](LICENSE).
