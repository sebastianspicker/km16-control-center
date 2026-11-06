# Contributing

Describe the behavior you changed and the checks you ran in your pull request.

## Development builds

Use macOS 14 or newer, full Xcode with a Swift 6 toolchain, Python 3.10 or newer,
Node.js, and CMake 3.16 or newer. Xcode supplies the Apple SDK, `xcrun clang`, and
Swift. The Python tools use only the standard library. GitHub Actions runs the
macOS build on a `macos-15` runner.

From the project root, validate the documented ad-hoc signed app-bundle build without
launching it:

```sh
bash script/build_and_run.sh --build-only
```

This creates `build/apps/KM16ControlCenter.app`, checks its `Info.plist`, fails
if the packaged preset bundle lacks the setup guides, and signs the bundle ad-hoc
(set `KM16_SIGN_IDENTITY` to use a keychain identity). It does not notarize,
package, launch, or exercise live integrations. The portable C core and browser
demo have their own build instructions in their linked guides below.

The source-build workflow runs automatically only for Dependabot-authored PRs
and remains manually dispatchable. On other PRs its `macos` job is skipped, and
GitHub counts a skipped required check as passed, so run the build commands above
(or dispatch the workflow) before merging. Before building, CI checks that no tracked file also matches the repository's
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

Factory presets are defined in Swift in `presets/Catalog/`, and their groups in
`ProfileGroup`. The JSON files in `presets/` (exports for the browser demo and for
importing) and the `groups` list in `site/app.js` are generated from them. After
changing either, run `swift run KM16PresetExport` from the project root and commit
the result; CI runs `swift run KM16PresetExport --check` and fails on stale files.
Setup guides live only in `presets/setup/`, which is bundled with the app and copied
as-is by Export Setup Files.

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
