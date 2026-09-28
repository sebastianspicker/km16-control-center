# Offline firmware findings

This analysis was completed on 2026-09-12 using only the saved board readback. It
did not enumerate or access the device, program firmware, or perform a physical
test. The readback contains 122,880 bytes from `0x08002000` and excludes the first
8 KiB. Three reads matched byte for byte, but each ended with
`LIBUSB_ERROR_PIPE`, so this is neither a completed full-chip dump nor evidence of
restoration capability. Readback SHA-256:
`5ff18a34b99de0e6ebb657f9f79df8e35a8b8e21459997096c24209bc493262e`.

The [live-board report](LIVE-FIRMWARE-ANALYSIS.md) covers the overall architecture.
This file adds code findings and lists the questions that the captured application
cannot answer.

## Recovered driver entries

The initial project contained no function entries for several indirect calls.
Four inspected callback tables at `0800F684`, `0800F8C8`, `0800F98C`, and `0800F9B4`
expose USB, channel and flash-driver routines. A separately installed character
output hook points to `0800B810`. Recovering them adds 29 entries, bringing the
export to 659 functions, each with decompiler output.

The analysis uses a separate local Ghidra project and exports under
`evidence/analysis/offline-20260912/`. The additional entries were recovered with
the [callback recovery script](../../scripts/analysis/ghidra/KM16DriverCallbacks.java).
The original 630-function project and exports remain preserved. A function count
is not a claim that every boundary, type or behavior is fully understood.

The readback, captures, Ghidra projects, exports, and generated analysis data are
excluded from releases. Their paths remain as provenance identifiers.

## HID debug console

The `FF31:0074` descriptor is the QMK/PJRC-style console format, with usage `75`,
32 input bytes and no report ID. This matches the console descriptor in
[QMK's source](https://github.com/qmk/qmk_firmware/blob/5734360a8699c8b7f77de0a8c62c9170861127fa/tmk_core/protocol/usb_descriptor.c).
The local comparison record `reference/qmk/sources.json` identifies that reference
revision; it is not asserted to be the vendor's source revision.

The acquired code independently establishes its implementation:

- Setup `08006200` installs pointer `0800B811` from literal `08006218` as the
  character-output hook through `0800677C`.
- Enqueue `0800B810` stores characters in RAM `20002540–2000263F`. Two byte indices
  at `20002640/20002641` wrap at 256. One slot is reserved, giving 255 queued
  characters; a character is dropped when full.
- Flush `0800B844` drains up to 32 bytes, zero-pads the rest and transmits to
  endpoint 5 IN / `85`, when USB is configured and that endpoint is idle.
- The main background path `08006A8A → 0800B994` services this alongside raw HID.

This diagnostic character stream is separate from VIA on `FF60:0061`. Silence
during ordinary input does not imply a broken console. A future host reader could
expose stock diagnostics, but this analysis did not read the interface.

## Flash geometry and capacity limits

The recovered flash vtable begins at `0800F988`; getter `0800D7E0` returns the
descriptor at `0800F9E0`. Its seven words are:

```text
00000003 00000002 00000100 00000000 00000800 08000000 00080000
```

The driver models 256 uniform sectors of 2048 bytes, based at `08000000`, with
2-byte programming units. Its model therefore spans 512 KiB. This is a
compiled software geometry, not proof of the installed flash capacity.

Backing discovery `08007770` separately reads the low 16 bits at `1FFFF7E0`, scales
the KiB value by 1024, skips model sectors outside that limit, and reserves the
last 8192 bytes inside it. For a 128 KiB value, its selected sector indices would
be 60–63, corresponding to `0801E000–08020000`; that is consistent with the acquired
settings placement. The actual identification-register value was not captured.

| Recovered function | MCU-side behavior |
| --- | --- |
| `0800D7E8` | Memory-mapped flash read, rejected while the driver is erasing |
| `0800D812` | Programs aligned halfwords, pads a partial word with `FF`, waits for busy to clear, checks protection/program errors and readback |
| `0800D8AA` | Returns unsupported status for the erase-all callback |
| `0800D8AE` | Starts a sector erase using the calculated address and the compatible FLASH control bits |
| `0800D8E6` | Polls erase completion and restores driver state |
| `0800D916` | Checks 2048 bytes for erased `FFFFFFFF` words |

The driver uses the compatible unlock values `45670123` and `CDEF89AB`, PG/PER/
STRT control bits, and FLASH registers at `40022000`. These values add compatibility
evidence but do not distinguish ST silicon from a compatible implementation.
The scaffold deliberately has no flash writer or linker memory map based on this
unverified physical geometry.

## Debug-port behavior

Initialization `0800448C` reads AFIO MAPR at `40010004`, clears mask `07000000`, and
sets `04000000`. Under the local reference definitions in
`reference/stm32f103xb.h`, this is SWJ_CFG=4, disabling both JTAG and SWD. This is
a volatile runtime register setting, not evidence of permanent readout protection.

PB4 is used by an encoder and overlaps a JTAG function on the compatible map.
That explains a reason to release JTAG pins, but does not establish a need to
disable SWD too. A future custom hardware port should preserve SWD during bring-up;
it must verify pin ownership before choosing its alternate-function configuration.
No option bytes, silicon ID, protection level or debug connection was read.

## Encoder event handling

Decoder `0800954C` stores the previous phase state and adds a signed transition from
the 16-byte table at `0800F464`. It emits according to this rule:

1. A changed phase state updates the signed accumulator.
2. An event is attempted at `accumulator >= 4` or `<= -4`, or when the new state
   is 3 and the accumulated value is nonzero.
3. The sign selects the logical direction. The accumulator resets after the
   attempt, including when the event queue is full.

Four transitions are therefore the normal full-cycle threshold, though a shorter
run ending at state 3 can also emit an event. The signs do not encode mechanical
detents or physical clockwise direction.

Queue `08009444` is a four-slot ring with three usable events. Its consumer
`08009384` produces paired synthetic press/release processing at logical locations
`FC00|index` or `FD00|index`. All three encoders share this implementation and are
polled through `080095BC`; no separate bottom-knob acceleration was found.

The scaffold currently exposes the signed Gray-transition primitive, rather than
claiming full vendor event/queue parity. Its README records this boundary.

Matrix debounce is global across the four row samples: any new candidate restarts
the stability timer; an unchanged candidate commits only after strictly more
than 5 ms (`080069AC`, `08006A10`). It is not four independent row timers or a
fixed sleep after every key event.

## Sleep states and wake sources

Sleep helper `0800375C` drives all six matrix columns low through GPIO BRR
(`+14`), configures PA0–PA3 as pulled-up inputs, and enables both EXTI edges for
those four rows. A pressed switch can then pull its row low without an active
column scan. This differs from normal scanning, where one selected column is low
and the other columns return to pulled-up inputs.

The reviewed sleep bodies `0800394C`, `08003B2C`, and `08003D18` additionally enable
both-edge interrupts for PB4, PB5, PA6 and PC14. PA7 and PC15 are the other
encoder phases, but are not configured as direct EXTI wake sources in these bodies.
`08003D18` also configures EXTI18 for USB wake. Helper `0800DCB0` programs routing,
IMR, EMR, RTSR and FTSR; its body does not clear the pending register itself.

Other recovered states:

- Setup `08004450` leaves PA8 high, PB7 low, and PB9 as a floating input.
  Mode 3 explicitly sets the output latch high before input-pull configuration;
  mode 6 is general-purpose push-pull output in the compatible map.
- The sleep code touches PD0/PD1, not PC0/PC1: `40011400` is GPIOD. These are
  oscillator-related pins under the compatible family mapping; the code alone
  does not identify the fitted oscillator or package.
- GPIO modes and clocks are restored after WFI. The surrounding mode/flag state
  selects thresholds including strict `>20,000 ms`, `>60,000 ms`, and `>500 ms`;
  these are conditional paths, not one universal auto-sleep duration.
- PB7 remains tied to the LED-enable state. PA8's external net and the physical
  switches/regulators remain unidentified.

## Battery calculation and display

The ADC estimator is unchanged: ten readings each of PB1/channel 9 and internal
reference/channel 17, discard each set's minimum and maximum, average the other
eight, then calculate `floor(ADC9 * 1764 / ADC17)`. Its physical units and
calibration remain unmeasured.

The integer percent function `08002FE0` uses these inclusive upper endpoints:

| Input `v` | Output |
| --- | --- |
| `3201–3300` | `floor((v−3200)/20)` |
| `3301–3470` | `5 + floor((v−3300)/34)` |
| `3471–3630` | `10 + floor((v−3470)*30/160)` |
| `3631–3760` | `40 + floor((v−3630)*20/130)` |
| `3761–3930` | `60 + floor((v−3760)*20/170)` |
| `3931–3980` | `80 + floor((v−3930)/10)` |
| `3981–4150` | `85 + floor((v−3980)*14/170)` |
| `4151` and above | `100` |

Exactly 3200 preserves the previous percentage because it misses the range
branches. Below 3200 the normal result is zero, except values at or below 899 with
PB9 high produce 100. At 4150 the result is 99, not 98. An independent integer
model checks the boundaries and the entire 16-bit input range; it is a static
model, not an emulator or a measurement.

Smoothing `080030C8` permits upward changes in state 1 and downward changes in
other ordinary states, one percentage point after three qualifying updates.
State 2 forces both working/display values to 100 after its second qualifying
invocation. Exact charger-state electrical meanings remain unresolved.

Battery display `080042AC`, when enabled, clears the RGB buffer and fills a bar
through key LED indices `12,13,14,15,11,10,9,8,4,5`. Values 11–30 use red,
31–49 yellow, and 50–100 green; 100 lights ten key positions. Values 0–10 leave
this battery bar blank. This display path is not evidence of an electrical
low-voltage cutoff.

## Development status and open questions

The [custom scaffold](../../firmware/custom/README.md) builds a portable C core,
native demonstration, and compile-only Cortex-M3 objects. The source uses
recovered constants and behavior, with no vendor binary or decompiled function
linked into the custom core. It does not yet provide startup, a linker map, a
hardware HAL, USB/VIA, radio state handling, persistent settings, or a complete
key/layer/macro engine. It cannot currently boot the board.

The local hardware contract
`evidence/analysis/offline-20260912/hardware-contract.json` and the
[extractor](../../scripts/analysis/extract-hardware-contract.py) retain the
checked offsets and calculations for continued development.

| Remaining question | Why this application readback does not settle it |
| --- | --- |
| Exact MCU and actual flash/RAM capacity | Compatible constants are shared by multiple chips; the silicon-register values and package marking are absent |
| First 8 KiB bootloader and recovery behavior | Outside the upload window; application marker/reset expectations do not reconstruct its implementation |
| Radio chip and radio firmware | The main MCU's UART messages expose a peer contract, not the peer's internal hardware/firmware |
| LED IC, eleven non-key LED positions, matrix diodes | Neither part markings nor those physical positions/diodes are encoded in the recovered tables |
| PA8 net, regulator/charger/load switch, voltages, battery capacity | GPIO state and ADC arithmetic do not reveal the physical circuit/component values |
| Actual timing, power draw and protocol compatibility | Requires connected tests or electrical measurements |

Static analysis may still clarify effects, custom keycodes, and protocol behavior.
Physical details require evidence from the board.
