# KM16 Pro knob mapping

This mapping was verified on 2026-09-12 against a SmartCloud KM16pro, USB
`28e9:3145`, using isolated, input-only captures of all four interfaces. Before
testing, the device owner restored the previously mapped layer. Its numerical ID
is unknown.

| Control | Clockwise | Counterclockwise | Press |
| --- | --- | --- | --- |
| Upper-left knob | Page Down | Page Up | No host-visible report; function unconfirmed |
| Upper-right knob | Next Track | Previous Track | Play/Pause |
| Large bottom knob | Volume Up | Volume Down | Switches layer, confirmed by physical observation; no HID report |

Matching isolated physical actions to decoded HID reports confirms all six rotation
assignments and the upper-right press. The upper-left press may be unassigned or
may perform a local function; a silent capture cannot distinguish between them.
The bottom press changes layers, but neither its target layer nor its cycle is known.
That behavior comes from physical observation, not a decoded USB command.

The large knob turns smoothly without mechanical detents. It was rotated in
separate bursts with pauses. Its two clockwise pulses and three counterclockwise
pulses therefore cannot be compared to a requested count of three physical clicks.

## Report decoding

All captured events arrived on the composite interface (`0001:0002`). Keyboard
report `0x06` contains the ID byte, one modifier byte, and a 240-bit usage bitmap.
Consumer report `0x04` contains the ID byte and one little-endian 16-bit usage.

| Action | Usage page | Usage | Press/release pairs |
| --- | --- | --- | ---: |
| Upper-left clockwise | Keyboard `0x07` | `0x4E` Page Down | 3 |
| Upper-left counterclockwise | Keyboard `0x07` | `0x4B` Page Up | 3 |
| Upper-right clockwise | Consumer `0x0C` | `0xB5` Next Track | 3 |
| Upper-right counterclockwise | Consumer `0x0C` | `0xB6` Previous Track | 3 |
| Bottom clockwise | Consumer `0x0C` | `0xE9` Volume Increment | 2 |
| Bottom counterclockwise | Consumer `0x0C` | `0xEA` Volume Decrement | 3 |
| Upper-right press | Consumer `0x0C` | `0xCD` Play/Pause | 1 |
| Upper-left press | None observed | Not applicable | 0 |
| Bottom press | None observed | Not applicable | 0 |

The nine isolated runs contain 36 reports forming 18 active/release pairs. All
processes exited successfully and all original capture checksums were verified.
Neither vendor interface emitted a report during these tests. This describes
current firmware mappings; it does not establish raw physical encoder IDs, MCU
identity, or firmware configuration commands.

`evidence/captures/knob-mapping-summary.json` contains the machine-readable results,
acquisition directory names, and device-owner confirmations. Each acquisition keeps
raw interface logs, a merged timestamped timeline, capture metadata, checksums, and
a separate confirmation record. Confirmations were added during or after acquisition.
The summary records their hashes; a separate file preserves the later bottom-clockwise
correction.

Raw captures and generated summaries are excluded from releases. The paths and
report counts identify the original acquisitions.

The earlier upper-left clockwise run at `20260912T100743.637584Z` is excluded
because the device owner subsequently restored the prior layer and repeated the
action. The verified replacement is
`knob-upper-left-cw-20260912T100929.988034Z`.

## Confirmed key layout

The device owner confirmed the earlier inferred physical mapping and identified the
bottom-left key as Fn:

| Row | Left | Second | Third | Right |
| --- | --- | --- | --- | --- |
| Top | 1 | 2 | 3 | 4 |
| Second | 5 | 6 | 7 | 8 |
| Third | 9 | 0 | Up | Enter |
| Bottom | Fn | Left | Down | Right |

Usage names follow the [USB HID Usage Tables](https://www.usb.org/sites/default/files/hut1_7.pdf).
