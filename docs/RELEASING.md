# Releasing

Source releases include the app, portable firmware core, presets, tests, and
research reports. Vendor firmware, board readbacks, raw captures, and local
analysis projects are excluded. No flashable custom firmware is provided.

## Source release

1. From a clean checkout on macOS 14 or newer, run
   `bash scripts/verify-source.sh` using full Xcode with Swift 6, Python 3.10 or
   newer, Node.js with `node --test`, and CMake 3.16 or newer.
2. Run `bash script/build_and_run.sh --build-only` and inspect the unsigned bundle
   at `build/apps/KM16ControlCenter.app`. This validates bundle assembly and its
   `Info.plist`; it does not sign, notarize, package, launch, or test integrations.
3. Review the [development status](development/IMPLEMENTATION-LEDGER.md). Include
   user-visible changes and known limitations in the release notes.
4. Inspect `git ls-files`. Then run
   `git ls-files --cached --ignored --exclude-standard`; it must print nothing.
   Ignore rules do not remove files already tracked. Include `LICENSE`; check
   redistribution terms for any third-party additions.
5. Update the version of each component being released: the app bundle version is
   in `script/build_and_run.sh` (currently `0.2.0`); the C core version is in
   `firmware/custom/CMakeLists.txt` (currently `0.1.0`).
6. Commit the reviewed source, then tag that exact commit.

GitHub generates source archives for tags. To prepare one locally from the reviewed
commit:

```sh
mkdir -p dist
git archive --format=zip --prefix=km16-control-center/ \
  --output=dist/km16-control-center-source.zip HEAD
```

Extract the archive, inspect its contents, and run the source checks before
attaching it to a release. Avoid zipping the working directory: ignored data,
credentials, and build products may be present.

GitHub publication covers the reviewed source and generated source archive only.
The workflow builds and tests source but does not create, sign, upload, or publish
a binary release.

## Browser demo

The separate **Browser demo** workflow publishes the static mockup to GitHub Pages
after Pages is configured to use GitHub Actions. It deploys only the allowlisted
`dist/site` output, never the repository root. See the [demo guide](../site/README.md)
for local preview and first-time setup. A deployed demo does not distribute the
native app or provide live device and desktop actions.

## Mac app release

`bash script/build_and_run.sh --build-only` creates an unsigned development bundle.
A binary release also needs signing, notarization, stapling, packaging, and launch
checks on a clean Mac running a supported macOS version. Keep signing credentials
outside the repository.

Check profile import/export, recovery, unsaved-change dialogs, keyboard navigation,
VoiceOver, resizing, and the overlay. Test advertised desktop, OBS, and Codex actions
with their target applications; offline fixtures cannot verify live delivery.

The app does not consume live pad input or write VIA settings. The C core lacks
board startup code, a linker configuration, and a HAL. Its host binaries and
Cortex-M3 object files are not device firmware.
