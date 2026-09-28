#!/bin/bash
set -euo pipefail

KM16_MODE="${1:-run}"
KM16_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KM16_APP="$KM16_ROOT/build/apps/KM16ControlCenter.app"
KM16_BINARY="$KM16_APP/Contents/MacOS/KM16ControlCenter"
KM16_BUNDLE_ID="org.local.KM16ControlCenter"

case "$KM16_MODE" in
  run|--build-only|--debug|--logs|--telemetry|--verify) ;;
  *) echo "usage: $0 [run|--build-only|--debug|--logs|--telemetry|--verify]" >&2; exit 2 ;;
esac

swift build --package-path "$KM16_ROOT"
KM16_BIN="$(swift build --package-path "$KM16_ROOT" --show-bin-path)"
KM16_BUILT="$KM16_BIN/KM16ControlCenter"

# Rebuilds preserve user edits. Only an explicitly isolated verification instance may be restarted.
python3 - "$KM16_BINARY" "$KM16_MODE" "$KM16_ROOT/.state/companion-ui-test/" <<'PY'
import os, signal, subprocess, sys, time
target, mode, test_prefix = sys.argv[1:]
processes = subprocess.check_output(["ps", "-axo", "pid=,comm="], text=True)
matched = []
for line in processes.splitlines():
    fields = line.strip().split(maxsplit=1)
    if len(fields) == 2 and fields[1] == target:
        pid = int(fields[0])
        arguments = subprocess.check_output(["ps", "-p", str(pid), "-o", "args="], text=True)
        if mode != "--verify" or "--profiles-path" not in arguments or test_prefix not in arguments:
            raise SystemExit("KM16 Control Center is running. Save and close its windows before rebuilding; existing edits were preserved.")
        try:
            os.kill(pid, signal.SIGTERM)
            matched.append(pid)
        except ProcessLookupError:
            pass
for _ in range(30):
    alive = []
    for pid in matched:
        try:
            os.kill(pid, 0)
            alive.append(pid)
        except ProcessLookupError:
            pass
    if not alive:
        break
    time.sleep(0.1)
else:
    raise SystemExit("This workspace's app did not exit; close it before rebuilding the bundle.")
PY

mkdir -p "$KM16_APP/Contents/MacOS"
cp "$KM16_BUILT" "$KM16_BINARY"
mkdir -p "$KM16_APP/Contents/Resources"
cp "$KM16_ROOT/packaging/AppIcon.icns" "$KM16_APP/Contents/Resources/AppIcon.icns"
# SwiftPM resource bundles are looked up in Contents/Resources at run time.
for bundle in "$KM16_BIN"/KM16ControlCenter_*.bundle; do
  rm -rf "$KM16_APP/Contents/Resources/$(basename "$bundle")"
  cp -R "$bundle" "$KM16_APP/Contents/Resources/"
done

# SwiftPM emits a flat resource bundle under Xcode 16 and a macOS-style Contents/Resources bundle
# under newer Command Line Tools. Validate the resource root produced by the active toolchain.
KM16_PRESETS_BUNDLE="$KM16_APP/Contents/Resources/KM16ControlCenter_KM16Presets.bundle"
if [[ -d "$KM16_PRESETS_BUNDLE/Contents/Resources" ]]; then
  KM16_PRESETS_RESOURCES="$KM16_PRESETS_BUNDLE/Contents/Resources"
else
  KM16_PRESETS_RESOURCES="$KM16_PRESETS_BUNDLE"
fi

# The preset setup guides must ship with the app: fail the build rather than package a bundle
# that would silently fall back to "This preset uses the actions shown on the pad" everywhere.
for required in setup/README.md setup/git-review.md setup/keybindings/git-review.code-keybindings.json; do
  if [[ ! -f "$KM16_PRESETS_RESOURCES/$required" ]]; then
    echo "Packaged KM16Presets bundle is missing $required" >&2
    exit 1
  fi
done
echo "Packaged KM16Presets bundle has the setup guides and keybindings fragment."
cat > "$KM16_APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>KM16ControlCenter</string>
  <key>CFBundleIdentifier</key><string>org.local.KM16ControlCenter</string>
  <key>CFBundleName</key><string>KM16 Control Center</string>
  <key>CFBundleDisplayName</key><string>KM16 Control Center</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleShortVersionString</key><string>0.2.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
plutil -lint "$KM16_APP/Contents/Info.plist"

km16_open_app() {
  if [[ -n "${KM16_PROFILES_PATH:-}" ]]; then
    /usr/bin/open -n "$KM16_APP" --args --profiles-path "$KM16_PROFILES_PATH"
  else
    /usr/bin/open -n "$KM16_APP"
  fi
}

case "$KM16_MODE" in
  --build-only) echo "$KM16_APP" ;;
  --debug) lldb -- "$KM16_BINARY" ;;
  --logs)
    km16_open_app
    /usr/bin/log stream --info --style compact --predicate 'process == "KM16ControlCenter"'
    ;;
  --telemetry)
    km16_open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$KM16_BUNDLE_ID\""
    ;;
  --verify)
    KM16_PROFILES_PATH="${KM16_PROFILES_PATH:-$KM16_ROOT/.state/companion-ui-test/profiles.json}"
    mkdir -p "$(dirname "$KM16_PROFILES_PATH")"
    km16_open_app
    python3 - "$KM16_BINARY" <<'PY'
import subprocess, sys, time
for _ in range(30):
    paths = subprocess.check_output(["ps", "-axo", "comm="], text=True).splitlines()
    if sys.argv[1] in [p.strip() for p in paths]:
        print("App process launched. A visible-window and interaction check is still required.")
        break
    time.sleep(0.1)
else:
    raise SystemExit("App process did not remain running")
PY
    ;;
  run) km16_open_app ;;
esac
