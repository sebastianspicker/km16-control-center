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
tests; builds the browser demo; configures, builds, and tests the portable C core
with CMake and CTest; and finishes with `swift build` and `swift test`. The Swift
tests use Swift Testing and synthetic fixtures without device access, desktop
input, OBS, or a real Codex session. Process tests launch and terminate local
synthetic fixtures and check a child-process heartbeat to verify cancellation.
When the private research captures exist in `evidence/captures`, the script also
replays them (`KM16_CAPTURE_ROOT`).

CI also validates the documented unsigned app-bundle build without launching it:

```sh
bash script/build_and_run.sh --build-only
```

This creates `build/apps/KM16ControlCenter.app`, checks its `Info.plist`, and fails
if the packaged preset bundle lacks the setup guides. It does not sign, notarize,
package, launch, or exercise live integrations.

Before building, CI checks that no tracked file also matches the repository's
ignore rules. This command must print nothing:

```sh
git ls-files --cached --ignored --exclude-standard
```

For focused checks:

```sh
swift test
swift test --filter KM16PresetsTests
python3 -m unittest discover -s scripts/tests -p 'test_*.py' -v
node --test scripts/tests/webhid-trace.test.cjs
```

To measure Agent Deck's text-update path (a fixed 280 KB diff and a mock
transport) and JSON-line framing of a fragmented 256 KiB frame, run:

```sh
KM16_BENCHMARK=1 swift test --filter Benchmark
```

The benchmarks check their results, then report seven timings after one warmup.
Compare runs built with the same configuration.

See the [firmware guide](firmware/custom/README.md) for C builds and the
[app architecture](docs/development/COMPANION-ARCHITECTURE.md) for package boundaries.

The app icon source is `packaging/AppIcon.png`. After changing
it, run `bash script/build_app_icon.sh` to regenerate the bundled `.icns` file.

The [browser demo](site/README.md) is a static HTML/CSS/JavaScript mockup. The source
checks validate its JavaScript syntax and build an allowlisted Pages artifact.
After UI changes, also check its interactions and desktop and narrow layouts in a
browser. Factory preset data comes from `presets/all.json` at build time.

## Compatibility and presets

Preserve profile IDs, schema migration, validation errors, and capture formats
unless a change is deliberate and documented. Preview and replay must remain
separate from actions that affect other apps or devices. Test observable behavior.

Factory presets are defined in Swift in `presets/Catalog/`. The JSON files in
`presets/` are generated exports for the browser demo and for importing; after a
preset change, regenerate them and commit the result:

```sh
KM16_WRITE_PRESET_EXPORTS=1 swift test --filter KM16PresetsTests
```

`swift test` fails when the exports are stale. Setup guides live only in
`presets/setup/`, which is bundled with the app and copied as-is by Export Setup
Files. Group changes in `ProfileGroup` also need the same change in `site/app.js`;
a test compares them.

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
