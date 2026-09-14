# Mac research tools

These tools inspect the KM16 Pro and record input reports. They run separately
from KM16 Control Center, which does not open the keyboard. See the
[board report](../analysis/LIVE-FIRMWARE-ANALYSIS.md) and
[key/knob mapping](../analysis/KNOB-MAPPING.md) for findings and their evidence.

Readbacks, captures, and third-party files are excluded from the public source.
Paths under `evidence/`, `firmware/vendor/`, and `reference/` identify the original
research inputs and outputs; they are not downloadable repository assets. The
commands below use ignored local directories. Capture commands access a connected
device, while offline analysis uses saved files.

## Device snapshot

From the project root:

```sh
python3 scripts/capture/snapshot.py
```

This reads the macOS registry for USB device `28e9:3145` and saves metadata, report
descriptors, and hashes under `evidence/device-snapshots/`. It does not open the
keyboard for report I/O. Exit status 3 means no matching HID interface was found.
Other connection modes or revisions may use different IDs.

The studied wired device identifies itself as `SmartCloud KM16pro`, with
`bcdDevice=0x0104`. Its four HID interfaces are:

| Usage page:usage (hex) | Maximum input bytes | Purpose in the studied firmware |
| --- | ---: | --- |
| `0001:0006` | 8 | Keyboard |
| `0001:0002` | 32 | Composite keyboard, mouse, system, and consumer reports |
| `FF60:0061` | 32 | VIA-style configuration interface |
| `FF31:0074` | 32 | Debug console |

The descriptors do not establish the MCU or firmware compatibility. `bcdDevice`
is not a confirmed semantic firmware version.

## Native input capture

Build the capture utility with the Apple SDK:

```sh
bash scripts/build.sh
mkdir -p evidence/captures
stamp=$(date -u +%Y%m%dT%H%M%SZ)
bin/hid-capture 28e9 3145 ff60 61 30 \
  > "evidence/captures/vendor-$stamp.jsonl" \
  2> "evidence/captures/vendor-$stamp.log"
```

The four IDs are hexadecimal and the duration is in seconds. The utility opens one
matching interface non-exclusively and registers an input callback. It does not
send output reports, reset the device, or write firmware. To record debug-console
input instead, use `ff31 74` for the usage page and usage.

JSON Lines records retain the callback bytes, report type, report ID, and timestamp.
The report ID is stored separately; the tool does not assume that it is also present
in the callback data. Use separate captures for different interfaces and record the
connection mode and action that produced each file.

Each interface capture is limited to 8 MiB of report payload or 20,000 reports,
whichever is reached first. Reaching either limit stops that helper with a nonzero
status and records partial evidence. `capture-knob.py` starts only the four listed
interfaces, applies the same limits while reading their JSON Lines files, and keeps
the globally timestamp-sorted timeline bounded. Its metadata marks helper, quota,
or evidence parsing failures as partial and its final status is nonzero.
Across the four fixed helpers, the accepted maximum is 32 MiB of payload and
80,000 reports. The runner will parse at most 82,468,864 bytes of source JSON Lines
across those helpers before marking evidence partial; the timeline contains only
the bounded, normalized rows from that input.

An idle configuration interface may produce no reports. An empty capture does not
confirm that capture works; check the log for access failures.

## WebHID traffic logger

`tools/browser/webhid-trace.js` records a page's WebHID API calls. It does not request
a device or send HID commands itself. The page being observed can still write to
the device.

1. Open VIA in a browser that supports WebHID.
2. Add the logger as a DevTools snippet and run it before authorizing the device.
3. Select the device in the console:

   ```js
   webhidTrace.select({ vendorId: 0x28e9, productId: 0x3145 });
   ```

4. Use the page's normal authorization and configuration flow.
5. Inspect, download, and stop the logger:

   ```js
   webhidTrace.snapshot();
   webhidTrace.download();
   webhidTrace.stop();
   ```

The default buffer holds the newest 2,000 records and counts dropped entries. It
records raw bytes, IDs, and success or failure. Outbound timestamps describe call
completion, not USB bus transmission time.

Reloading removes the logger. Workers, frames, other tabs, and cached method
references may bypass it, so the log is not a complete USB bus trace. Tests use
synthetic APIs; real VIA/browser/device behavior needs separate verification.
Review traces for personal data before sharing.

## Offline firmware analysis

Use an unchanged input file and record its origin, acquisition date, length, and
SHA-256. The fixed-offset analyzers accept only their pinned image hashes.
A filename or product name alone is not enough to choose an architecture, load
address, or replacement firmware.

Scripts in `scripts/analysis/` extract the reference and board applications,
reconstruct settings, and describe the recovered hardware contract. Use `--help`
for input and output arguments. Some defaults point to ignored paths from the
original analysis, so pass your own matching inputs explicitly. `render-board-map.py`
writes into local evidence.

Ghidra helper scripts are in `scripts/analysis/ghidra/`. Use your own Ghidra and Java
installation and keep analysis projects outside the source tree or under `evidence/`.
Machine-specific launchers are not distributed.

The three 122,880-byte application readbacks at `0x08002000` matched and passed the
embedded CRC check, but every upload ended with a PIPE error. The first 8 KiB are
absent; restoration is untested. The separate vendor image is not a verified
replacement for this board.

## Verification

```sh
bash scripts/verify-source.sh
```

This runs the public source checks without device access or excluded research
artifacts.
If you have the original snapshot, firmware, relocation manifest, and archived
files, you can also run:

```sh
bash scripts/verify-offline.sh
```

The second command validates saved hashes and reruns pinned analyses into `build/`.
It does not perform hardware acquisition or flashing.
