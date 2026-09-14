# V0101 reference firmware analysis

Analyzed offline on 2026-09-12, this report covers the supplied V0101 reference
image. It is a separate build, not a dump or backup of the connected unit. For
current board findings, saved settings, and hardware mapping, see
[LIVE-FIRMWARE-ANALYSIS.md](LIVE-FIRMWARE-ANALYSIS.md). The board comparison below
reflects evidence collected before the DFU readback.

Where the connected board and reference image differ, the board's descriptors,
captured inputs, and physical observations take precedence. Code and storage
findings below apply only to the reference build.

## Connected-board context

A registry-only snapshot at
`evidence/device-snapshots/20260912T102734.604561Z/device.json`
confirms SmartCloud KM16pro, USB `28e9:3145`, `bcdDevice=0x0104`, four HID
interfaces, and 32-byte input/output reports on `FF60:0061`. It matches the
earlier snapshot used for the input captures. `bcdDevice` is the USB device release
field; its relationship to vendor semantic firmware versions is not established.

[KNOB-MAPPING.md](KNOB-MAPPING.md) remains the record of verified assignments:
upper-left Page Down/Up, upper-right Next/Previous Track and Play/Pause, bottom
Volume Up/Down and a user-observed layer switch. Upper-left press produced no HID
report; its actual local function was unconfirmed at this stage. The current layer
number, layer count, full stored configuration, and firmware contents had not yet
been read. The later results are in [LIVE-FIRMWARE-ANALYSIS.md](LIVE-FIRMWARE-ANALYSIS.md).

| Property | Connected board | Supplied reference binary |
| --- | --- | --- |
| VID:PID | `28e9:3145` | Same, descriptor at file `0xD8E9` |
| USB release field | `0x0104` | `0x0101` |
| `FF60:0061` reports | 32 bytes each direction | 64 bytes each direction |
| Other three report descriptors | Saved from registry | Exact byte matches |
| VIA protocol version | Unqueried | Dispatcher returns `0x000C` (12) |
| Layer count | Unqueried | Six |
| Firmware flash/base/MCU | Unknown | Static evidence described below |

The reference is therefore not descriptor-identical to the installed firmware.
Board tooling must use the live 32-byte report format and verify commands and
capacities against the board. A similar factory mapping does not establish protocol
compatibility or show that current settings match factory defaults.

## Artifacts and reproducibility

The analysis used these local files under `firmware/vendor/`:

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| `JOSN-IT32CTB0_WoAo_QMK_KM16Pro_ThreeModeKeyboard_V0101_20250424.json` | 4,911 | `b03b21e35039786774b1103d3bb50d7ccead33fd7b2a252b1aff28cae7cb7656` |
| `UpdataPack-IT32CTB0_WoAo_QMK_KM16Pro_ThreeModeKeyboard_V0101_CS1DE20E67_20250424.bin` | 57,156 | `d162ee27c2ac752278e6b71e6ebceb8bd74107be84fca1f14d7499792a07e351` |

These are user-supplied artifacts; the filename date and revision are vendor
labels, not independently established build timestamps or provenance signatures.
The filename's `CS1DE20E67` is not the DFU CRC recovered below; its meaning is unknown.

Vendor files, snapshots, captures, decompiler exports, and generated analysis
artifacts are excluded from releases. Their paths remain as provenance identifiers.

Run the deterministic, offline extractor:

```sh
python3 scripts/analysis/analyze-firmware.py \
  --snapshot evidence/device-snapshots/20260912T102734.604561Z/device.json \
  --output evidence/analysis/reference-20260912
```

It verifies the exact image hash and DFU CRC, extracts both complete factory tables,
decodes HID report lengths, and compares them with the board snapshot. It refuses
other firmware hashes because the recovered offsets are specific to this image.
The script writes `evidence/analysis/reference-20260912/analysis.json` and a
verification record at `evidence/analysis/reference-20260912/verification.json`.
The latter records passing checks and unverified device capabilities. `sha256.json`
in that directory hashes the analysis artifacts but excludes the mutable Ghidra
project.

Ghidra 12.1.3 imported the derived payload as `ARM:LE:32:Cortex` at `0x08002000`.
It recovered 617 function entries and produced C-like output for all 617. This is
automated decompilation, not original source recovery or proof of complete coverage.
Some functions include shared tail-call code and inaccurate inferred signatures;
assembly was consulted for consequential calls, widths, and constants.

- Project: `evidence/analysis/reference-20260912/ghidra/KM16Pro.gpr`.
- Original exports: `evidence/analysis/reference-20260912/exports/functions.tsv`.
- 34 analyst names: `evidence/analysis/reference-20260912/symbols.tsv`.
- Named C and assembly: `evidence/analysis/reference-20260912/annotated-exports/functions.tsv`.
- Scripts: `scripts/analysis/ghidra/KM16Init.java`, `KM16Annotate.java`, `KM16Export.java`.
- Logs: `ghidra-initial.log` and `ghidra-annotated.log` in the analysis directory.

## Image format, startup, and processor clues

The file contains directly decodable little-endian ARM Thumb application code plus
a 16-byte DFU suffix. No whole-image decompression or decryption was needed. A
generic `file` identification as TTComp data is a magic-byte false positive.

All file offsets below refer to the original file or suffix-stripped payload;
their beginnings are identical. Flash address = file offset + `0x08002000`.

| Region or value | Recovered evidence |
| --- | --- |
| Application payload | File `[0, 0xDF34)`, 57,140 bytes |
| Linked application span | `[0x08002000, 0x0800FF34)` |
| Vector table | File `[0, 0x160)`; 88 words |
| Initial main stack pointer | `0x20000400` |
| Reset vector | `0x08002239`, Thumb bit set; instruction at `0x08002238` branches to startup `0x08002160` |
| Process stack pointer | Startup sets `0x20000C00` |
| Vector relocation | Startup writes `0x08002000` to VTOR `0xE000ED08`, corroborating the load base |
| Stack fill | `[0x20000000, 0x20000C00)` filled with `0x55555555` |
| Initialized data | ROM `0x0800FCE0` copied to RAM `[0x20000C00, 0x20000E54)` |
| Zeroed BSS | `[0x20000E58, 0x20002DB4)` |
| Application main | `0x08006C20` |

The application is linked 8 KiB above the usual flash base. The preceding bytes
are absent, so the bootloader itself is not included or identified by this analysis.
The startup, Thumb-2/BASEPRI instructions, and peripheral constants support a
Cortex-M3/M4-class target with an STM32F1-compatible register map. They do not prove
an STM32 rather than a compatible implementation, the exact IT32CTB0 part, or the
processor installed in the connected board. Ghidra's RAM/peripheral windows are
analysis conveniences, not measured hardware capacities.

DFU suffix bytes:

```text
ff ff 03 00 af 1e 00 01 55 46 44 10 d7 a8 75 6b
```

They encode device-release wildcard `FFFF`, PID `0003`, VID `1EAF`, DFU `0100`,
`UFD`, length 16, and CRC `6B75A8D7`. Both `dfu-suffix --check` and an independent
CRC calculation validate it: `zlib.crc32(file_without_last_4_bytes) XOR FFFFFFFF`.
This is integrity metadata, not authentication or proof that the unit exposes that
bootloader ID. A DFU suffix is not transferred as application firmware by dfu-util;
see the [dfu-suffix documentation](https://dfu-util.sourceforge.net/dfu-suffix.1.html).

## VIA definition and factory tables

The JSON is a VIA device definition that describes the interface layout and
controls. It is not a saved keymap or EEPROM backup. This distinction follows the
[VIA definition specification](https://github.com/the-via/website/blob/master/docs/specification.md).
It declares a 4×6 logical matrix with 16 visible keys and three knob press positions:
upper-left `(0,4)` / e0, upper-right `(0,5)` / e1, bottom `(2,5)` / e2. Five logical
matrix cells are unused in the displayed layout. These coordinates and encoder
indices are definition-derived, not independently measured physical wiring.

Factory keymap getter `0x08004C88` points to `0x0800ECA0` (file `0xCCA0`):
six layers × four rows × six columns × two bytes = 288 bytes, little-endian.
Factory encoder getter `0x08004CB0` points to `0x0800EC58` (file `0xCC58`):
six layers × three encoders × two directions × two bytes = 72 bytes.

| Reference factory layer | Visible keys | Fn `(3,0)` | Bottom press `(2,5)` | Rotations |
| --- | --- | --- | --- | --- |
| 0 | `1 2 3 4 / 5 6 7 8 / 9 0 Up Enter / Fn Left Down Right` | `MO(5)` | `0x5201` | Six assignments below |
| 1 | Same, but number keys have Shift modifiers | `MO(5)` | `0x5202` | All `KC_NO` |
| 2 | Unassigned except Fn and bottom press | `MO(5)` | `0x5203` | All `KC_NO` |
| 3 | Unassigned except Fn and bottom press | `MO(5)` | `0x5204` | All `KC_NO` |
| 4 | Unassigned except Fn and bottom press | `MO(5)` | `0x5205` | All `KC_NO` |
| 5 | Host, reset, battery, lighting and layer controls | `KC_NO` | `0x5200` | All `KC_NO` |

The full raw tables are retained in `analysis.json`, including unused cells.
Layer 0 rotations are e0 `004E/004B`, e1 `00AB/00AC`, e2 `00A9/00AA`.
These correspond to Page Down/Up, Next/Previous Track, and Volume Up/Down. The
getter indexes each stored pair with `(direction_boolean XOR 1)`; the first and
second words match the captured clockwise and counterclockwise actions respectively.
QMK media keycodes differ numerically from the Consumer-page usages sent to USB.

Layer-0 upper-right press is `00AE` (Play/Pause). Upper-left is `7820`, handled
locally by the custom key processor at `0x08004900`: under its state conditions,
pressing it toggles two lighting-control flags, persists them, and consumes the key.
This may explain the silent host capture in the reference build. It does not confirm
that the connected board's upper-left press controls lighting.

The `0x5200..0x5205` keys are intercepted by this firmware and passed to
`0x08004E76`, which stores the default-layer mask `1 << index` at logical EEPROM
byte 3 and applies it. The reference factory bottom presses therefore form a
six-layer progression. Separately, custom `0x7E07` (JSON “Layer Toggle”) only
switches between default masks 1 and 2, i.e. layers 0 and 1; it is not the same
operation as the factory bottom-knob cycle. Neither sequence is verified on the unit.

Custom `0x7E00..0x7E07` follow the JSON order: USB, Bluetooth slots 1/2/3, 2.4 GHz,
reset, battery display, layer toggle. The code also has hold timers around host/reset
controls. Those names and timers are not a fully decoded pairing/reset procedure.
Legacy lighting values `78xx` remain raw where exact aliases are uncertain.

## Configuration dispatcher and storage

The reference call path is:

```text
main08006c20 → raw poll08006c0e → dispatcher0800abaa
                                  ├ vendor intercept08004bc8
                                  ├ keymaps / encoders / macros / lighting
                                  └ raw reply0800ba60 (64 bytes)
```

These command interpretations come from this image's branches, cross-checked
against [QMK's VIA command declarations](https://github.com/qmk/qmk_firmware/blob/master/quantum/via.h).
Current upstream declarations provide vocabulary, not proof of the binary's source
revision. The reference returns protocol 12 even though current upstream differs.

| Command hex | Reference behaviour |
| --- | --- |
| `01` | Protocol version; returns bytes 1–2 `00 0C` |
| `02` | Get keyboard value: uptime, layout options, matrix state; firmware-value subcommand returns zero |
| `03` | Set keyboard value |
| `04` / `05` | Get / set keycode using layer,row,column and BE16 value |
| `06` | Reset keymaps and encoders to factory tables |
| `07` / `08` / `09` | Set / get / save lighting values |
| `0A` | Vendor interception described below, overriding the standard EEPROM-reset command for accepted subcommands |
| `0B` | No normal bootloader-jump case; falls through to `FF` |
| `0C` / `0D` | Macro count 16 / buffer size 3690 |
| `0E` / `0F` / `10` | Macro read / write / reset |
| `11` | Layer count 6 |
| `12` / `13` | Keymap buffer read / write |
| `14` / `15` | Encoder get / set; BE16 value |

Lighting channels 2 and 3 correspond to the definition's underglow and backlight
menus. Handler `0x0800AB88` contains brightness scaling between the exposed 0–255
range and an internal range around 0–160, plus effect, speed, and color handling.
This is another reason not to equate UI values directly with raw storage bytes.

The reference logical EEPROM is 4096 bytes, backed by flash emulation:

| Logical byte range, inclusive | Size | Contents |
| --- | ---: | --- |
| `0000–002D` | 46 | Metadata and configuration, including default-layer mask at byte 3 |
| `002E–014D` | 288 | Dynamic keymaps, six 4×6 layers |
| `014E–0195` | 72 | Dynamic encoder mappings |
| `0196–0FFF` | 3690 | Macro buffer |

Unlike the factory ROM tables, stored dynamic keycodes are big-endian:

```text
keycode offset = 0x2e + layer*48 + row*12 + column*2
encoder offset = 0x14e + layer*12 + encoder*4 + (direction ? 0 : 2)
macro offset   = 0x196 + macro_buffer_offset
```

`0x080073B0` maintains a RAM shadow and emits compact halfword journal records.
Compaction at `0x080074C0` writes 0x800 halfwords (4096 bytes) of shadow data plus
eight bytes of integrity data, then starts the append position at `0x1008`.
`0x080078F8` reads the low flash-size information from `0x1FFFF7E0` and walks flash
region descriptors backwards until at least `0x2000` bytes are selected. This
supports an 8 KiB backing reservation near the runtime flash end, subject to region
geometry. An absolute storage address and exact flash capacity are unproven.

## Vendor bridge and wireless clues

The reference vendor intercept checks byte 0 for `0x0A`. It normally constructs a
66-byte frame `55 40 <64 request bytes>` and writes it through `0x0800B32C`.
Subcommands `00` and `55` first enqueue sixty zero bytes and call a sleep routine
with argument 500. After the frame, the sleep argument is 300. These arguments are
not presented as measured wall-clock milliseconds without validating the RTOS tick
conversion. Subcommand `02` copies only 28 request bytes but still sends 66 bytes;
the remaining tail is not explicitly initialized in the recovered assembly.
The handler consumes accepted commands before the normal VIA reply path. Its
subcommands' higher-level meanings and response path remain incompletely decoded.

The outgoing queue is at `0x20002BFC`, inside the serial object at `0x20002BCC`.
Initializer `0x0800E0E4` assigns that object register base `0x40013800`, consistent
with USART1 in an STM32F1-compatible map. `0x0800B2C0` configures GPIOA masks
`0x200` and `0x400`, consistent with pins PA9 and PA10 under that map. This identifies
the reference software's pin selections, not accessible pads on the physical PCB.

Caller `0x0800454C` passes `0x70800` = 460,800 baud to `0x0800B2C0`.
The initializer writes that value into the config passed to the serial driver.
The generic fallback table contains 38,400 baud, but this caller supplies its own
configuration. This is a configured reference-build rate, not a measured waveform.

Strings include `KM16pro BT5.3`, `SmartBLE`, QMK-style lighting/NKRO diagnostics,
and USB names. Combined with the serial bridge, they suggest a split application /
wireless-module architecture. The downstream module identity, actual wireless
protocol, module firmware, PCB routing, and electrical levels are unknown. The
presence of a Bluetooth name does not prove this file contains the radio stack.

## Scope and safety boundary

The reference image supplies candidate protocol and storage semantics; it does not
replace evidence from the unit. The later application readback establishes
the unit's protocol version, layer count, stored encoder assignments, and lighting
behavior; those results are documented in
[LIVE-FIRMWARE-ANALYSIS.md](LIVE-FIRMWARE-ANALYSIS.md).

This reference-image analysis sent no configuration request, feature/output report,
vendor command, reset, bootloader entry, or flash operation. Registry reads provided
the board inventory. The separately documented DFU application-region readback
begins at
`0x08002000`, contains 122,880 bytes, excludes the first 8 KiB, and all matching
reads ended with `LIBUSB_ERROR_PIPE`. It is not a full-chip dump, does not establish
restoration capability, and has not been used for restoration. The provided image
was not flashed or executed, and captured physical
key/knob mapping records were preserved rather than replaced with factory values.
