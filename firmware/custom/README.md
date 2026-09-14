# KM16 Pro custom firmware scaffold

This directory contains an offline C11 scaffold for a small, portable core inferred
from the acquired KM16 Pro application. It is incomplete: it does not produce a
flashable image or include hardware access and flashing paths.

## Build and run

From this directory:

```sh
cmake -S . -B build
cmake --build build
ctest --test-dir build --output-on-failure
./build/km16_custom_demo
```

When `clang` is installed, the optional target checks that the portable source
files compile as freestanding Cortex-M3 Thumb objects:

```sh
cmake --build build --target cortex-m3-objects
```

That target only emits `.o` files under `build/cortex-m3`. It has no startup code,
interrupt vectors, linker script, bootloader contract, HAL implementation, or
binary-image step.

## Implemented core

- Board-profile tables describe the 4x6 matrix pins, three encoder phase pairs
  and press coordinates, peripheral-role pins, matrix-to-key-LED map, animation
  coordinates, and recovered LED groups. Names remain compatible-map labels.
- Matrix-wide debounce accepts a sample after a strict `> 5 ms` stable interval.
  Its unsigned subtraction is intentionally safe across a `uint32_t` millisecond
  counter wrap, assuming intervals shorter than half the counter range.
- The encoder decoder applies the recovered 16-entry signed Gray transition table.
  It exposes transition sign and a saturating signed count. A sign is deliberately
  not named clockwise/counterclockwise, and no mechanical detent resolution is
  imposed. It does not yet implement the vendor event layer, whose recovered rule
  emits at accumulator `>= 4` or `<= -4`, or on changed state 3 with a nonzero
  accumulator, then resets the accumulator.
- The LED encoder emits 27 pixels as GRB-compatible, most-significant-bit-first
  compare cells, using `9` for zero and `30` for one, followed by 170 zero cells.
  The exact output size is `27 * 24 + 170 = 818` bytes.
- The bounded UART builder emits `0x55 | body_length | body`, where the body is at
  most 255 bytes and the largest frame is 257 bytes. It adds no checksum, escaping,
  terminator, or inferred command semantics.
- The demonstration and tests run those production core functions on the host;
  they do not substitute a mock implementation of the primitives.

## Hardware boundary and remaining work

`include/km16/hal.h` defines the future boundary for monotonic time, matrix and
encoder sampling, LED transfer, and UART transmission. A real port still needs a
verified MCU target and RAM size, startup and linker definitions, clock setup,
interrupts, GPIO electrical configuration, timer/DMA ownership, UART buffering,
power behavior, USB descriptors and reports, bootloader compatibility, and board
level validation.

The stock application writes AFIO configuration that disables JTAG and SWD. This
scaffold does not reproduce that behavior. A future hardware port should preserve
SWD unless a verified board requirement justifies changing it.

A board port still needs keymaps, layer state, macros, settings persistence, USB
HID/VIA processing, radio handling, sleep and wake policy, battery measurement,
and lighting effects. The custom core has never been linked for the board, run on
hardware, flashed, or used to send device traffic.

## Evidence and provenance

The constants and ordering were transcribed from these repository documents and
local research artifacts. The `evidence/` paths are provenance identifiers; those
files are excluded from the public checkout:

- `../../docs/analysis/LIVE-FIRMWARE-ANALYSIS.md`
- `../../evidence/analysis/live-20260912/hardware-inputs.json`
- `../../evidence/analysis/live-20260912/led-layout.json`
- `../../evidence/analysis/live-20260912/settings.json`
- `../../evidence/analysis/live-20260912/annotated-exports/`
- `../../evidence/analysis/live-20260912/wireless-findings.md`
- `../../docs/analysis/OFFLINE-FINDINGS.md`
- `../../evidence/analysis/offline-20260912/hardware-contract.json`
- application readback SHA-256
  `5ff18a34b99de0e6ebb657f9f79df8e35a8b8e21459997096c24209bc493262e`

Those artifacts establish behavior through static analysis of an application
readback containing 122,880 bytes from `0x08002000`. Three reads matched byte for
byte, but each ended with `LIBUSB_ERROR_PIPE`. The readback excludes the first
8 KiB and is not a full-chip dump or evidence of restoration capability. These
artifacts do not identify the exact MCU silicon, SRAM size, radio, LED IC, PCB nets,
or unseen bootloader behavior. Pin names are labels under an STM32F1-compatible
peripheral map. Encoder index 2 on PC14/PC15 remains the candidate lower encoder
pending physical verification.

Vendor binaries, readbacks, captures, decompiler exports, and generated analysis
artifacts are excluded from releases. The paths above identify the original files.

The custom source in this directory is released under the repository's MIT License.
It does not copy decompiler output or vendor firmware functions. Vendor firmware
and third-party material retain their existing terms and are not relicensed.
