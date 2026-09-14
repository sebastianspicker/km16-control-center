# Project status

KM16 Control Center provides software profiles and desktop/service actions.
Direct pad integration remains unfinished. See the [app guide](../../apps/KM16ControlCenter/README.md)
for use and the [architecture](COMPANION-ARCHITECTURE.md) for implementation details.

## Available

| Area | Features |
| --- | --- |
| Profile library | 16 presets, 400 assignments, editing, grouping, import/export, matching, and undo/redo |
| Persistence | Schema migration, validation, bounded reads, atomic saves, backups, and recovery copies |
| Editor | Pad preview, assignment inspector, setup guides, status messages, and shared overlay |
| Desktop actions | Shortcuts, Unicode text, app launching, commands, media/audio, scrolling, and windows |
| Agent Deck | Codex app-server lifecycle, workspace threads, prompts, output/diffs, and request-specific replies |
| OBS | WebSocket v5 authentication, scene navigation, recording, Studio Mode, and source audio |
| Saved input | Stock-layer HID decoding and simulation replay |
| Firmware core | Board tables, debounce, Gray-code transitions, LED encoding, bounded UART frames, and host demo |

## Testing gaps

Public source checks cover profiles, parsers, invalid inputs, recovery, store
transitions, factory assignments, local protocol fixtures, and portable C functions.
Capture replay and preservation checks require the original research artifacts,
which are excluded from releases.

Manual UI checks have covered profile selection, split-view resizing, inspector
scrolling, collapse/reopen behavior, and selected editors. Keyboard navigation,
VoiceOver, import/save/close flows, and the overlay across displays still need
broader testing; the automated source checks do not cover them.

Desktop input delivery, OBS recording/audio, application shortcuts, and authenticated
Codex use need tests with configured target applications. Offline fixtures and
successful builds do not verify these interactions.

## Not yet implemented

- Connect stock HID input and prevent duplicate handling of events already consumed
  by macOS.
- Implement and test VIA settings, device-layer synchronization, and LED control.
- Confirm the MCU, memory limits, electrical behavior, radio, and bootloader/recovery
  behavior before porting firmware to the board.
- Add startup code, a linker configuration, and a HAL. The Cortex-M3 target currently
  compiles objects only.
- Complete accessibility and live-integration testing.
- Sign, notarize, and test a binary Mac release on a clean machine.

The application readback excludes the first 8 KiB; restoration is untested.
See the [board report](../analysis/LIVE-FIRMWARE-ANALYSIS.md) for acquisition limits.
No flashable custom firmware is provided.
