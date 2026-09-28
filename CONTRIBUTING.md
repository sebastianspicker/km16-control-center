# Contributing

Describe the behavior you changed and the checks you ran in your pull request.

## Development builds

Use macOS 14 or newer, full Xcode with a Swift 6 toolchain, Python 3.10 or newer,
Node.js, and CMake 3.16 or newer. Xcode supplies the Apple SDK, `xcrun clang`, and
Swift. The Python tools use only the standard library. GitHub Actions runs the
macOS build on a `macos-15` runner.

From the project root, validate the documented unsigned app-bundle build without
launching it:

```sh
bash script/build_and_run.sh --build-only
```

This creates `build/apps/KM16ControlCenter.app`, checks its `Info.plist`, and fails
if the packaged preset bundle lacks the setup guides. It does not sign, notarize,
package, launch, or exercise live integrations. The portable C core and browser
demo have their own build instructions in their linked guides below.

Before building, CI checks that no tracked file also matches the repository's
ignore rules. This command must print nothing:

```sh
git ls-files --cached --ignored --exclude-standard
```

See the [firmware guide](firmware/custom/README.md) for C builds and the
[app architecture](docs/development/COMPANION-ARCHITECTURE.md) for package boundaries.

The app icon source is `packaging/AppIcon.png`. After changing
it, run `bash script/build_app_icon.sh` to regenerate the bundled `.icns` file.

The [browser demo](site/README.md) is a static HTML/CSS/JavaScript mockup. Build its
allowlisted Pages artifact, then check interactions and desktop and narrow layouts
in a browser. Factory preset data comes from `presets/all.json` at build time.

## Compatibility and presets

Preserve profile IDs, schema migration, validation errors, and capture formats
unless a change is deliberate and documented. Preview and replay must remain
separate from actions that affect other apps or devices. Test observable behavior.

Factory presets are defined in Swift in `presets/Catalog/`. The JSON files in
`presets/` are generated exports for the browser demo and for importing; keep them
in sync with catalog changes. Setup guides live only in `presets/setup/`, which is
bundled with the app and copied as-is by Export Setup Files. Keep group changes in
`ProfileGroup` synchronized with `site/app.js`.

## Research contributions

Keep raw firmware, device captures, credentials, signing files, private logs, and
third-party material out of Git and GitHub issues. Use small synthetic examples and
remove personal data from logs and screenshots. Original research artifacts are
not part of a public checkout; see the [Mac research tools](docs/workflows/mac-tools.md)
for capture and analysis instructions.

Hardware reports should identify the device revision, connection mode, and method,
and distinguish physical observations from code analysis. Remove personal data
from logs before sharing them.

Contributions to this repository use the [MIT license](LICENSE).
