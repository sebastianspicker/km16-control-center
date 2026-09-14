#!/usr/bin/env python3
"""Decode the KM16 Pro live-image EEPROM-emulation replay journal.

This is a read-only decoder for the 2026-09-12 DFU backup.  It implements
the record reader recovered from the *live* image at 0x08007550 and its
complementing physical-word read at 0x08007808.  It does not write the source
dump; --output is an optional reconstructed 4096-byte logical EEPROM image.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path


FLASH_BASE = 0x08002000
EEPROM_SIZE = 0x1000
STORAGE_FILE_OFFSET = 0x1C000
JOURNAL_FILE_OFFSET = STORAGE_FILE_OFFSET + 0x1008
JOURNAL_END = STORAGE_FILE_OFFSET + 0x2000

METADATA_SIZE = 0x2E
KEYMAP_OFFSET = 0x2E
KEYMAP_LAYERS = 6
KEYMAP_ROWS = 4
KEYMAP_COLS = 6
KEYMAP_LAYER_STRIDE = KEYMAP_ROWS * KEYMAP_COLS * 2  # 0x30
ENCODER_OFFSET = 0x14E
ENCODER_LAYERS = 6
ENCODERS_PER_LAYER = 3
ENCODER_DIRECTIONS = 2
ENCODER_LAYER_STRIDE = ENCODERS_PER_LAYER * ENCODER_DIRECTIONS * 2  # 0x0c
MACRO_OFFSET = 0x196


class DecodeError(ValueError):
    pass


def decoded_word(image: bytes, offset: int) -> int:
    if offset < 0 or offset + 2 > len(image):
        raise DecodeError(f"word at file offset 0x{offset:x} is outside dump")
    raw = int.from_bytes(image[offset : offset + 2], "little")
    return (~raw) & 0xFFFF


def replay_type_zero(
    image: bytes, logical: bytearray, pos: int, low: int, high: int
) -> tuple[list[tuple[int, int]], int]:
    if pos + 4 > JOURNAL_END:
        raise DecodeError(f"truncated type-0 record at 0x{pos:x}")
    second = decoded_word(image, pos + 2)
    flags_and_length = low >> 3
    length = flags_and_length & 7
    address = ((low & 7) << 16) | (high << 8) | (second & 0xFF)
    payload = [second >> 8]
    consumed = 4

    # These conditions and their overlap intentionally match 0x08007550.
    for mask in (6, 4):
        if flags_and_length & mask:
            extra = decoded_word(image, pos + consumed)
            payload.extend((extra & 0xFF, extra >> 8))
            consumed += 2

    if not 1 <= length <= len(payload):
        raise DecodeError(f"invalid type-0 length at 0x{pos:x}: {length}")
    if address + length > EEPROM_SIZE:
        raise DecodeError(f"type-0 range at 0x{pos:x}: 0x{address:x}+0x{length:x}")
    writes = list(enumerate(payload[:length], address))
    logical[address : address + length] = payload[:length]
    return writes, consumed


def replay_journal(image: bytes) -> tuple[bytes, list[dict[str, object]], int]:
    """Return zero-base logical EEPROM, decoded journal records, and terminator.

    The live loader begins from a 4096-byte base snapshot then replays records
    from logical physical offset 0x1008.  In this backup the base page is
    erased, whose complemented reads are zero, so this reproduces the loader's
    all-zero starting buffer before replay.
    """
    if len(image) < JOURNAL_END:
        raise DecodeError(
            f"dump is {len(image):#x} bytes; need at least {JOURNAL_END:#x}"
        )
    if any(value != 0xff for value in image[STORAGE_FILE_OFFSET:STORAGE_FILE_OFFSET + EEPROM_SIZE]):
        raise DecodeError("Non-erased base snapshot requires checksum validation; this decoder handles this dump's erased base only")

    logical = bytearray(EEPROM_SIZE)
    records: list[dict[str, object]] = []
    pos = JOURNAL_FILE_OFFSET

    while pos < JOURNAL_END:
        header = decoded_word(image, pos)
        if header == 0:
            return bytes(logical), records, pos

        low = header & 0xFF
        high = header >> 8
        record_type = low >> 6
        writes: list[tuple[int, int]] = []
        consumed = 2

        if record_type == 1:
            address = low & 0x3F
            value = high
            logical[address] = value
            writes.append((address, value))

        elif record_type == 2:
            address = ((low << 9) & 0x3E00) | (high << 1)
            if address + 1 >= EEPROM_SIZE:
                raise DecodeError(f"type-2 range at 0x{pos:x}: 0x{address:x}")
            value = (low >> 5) & 1
            logical[address] = value
            logical[address + 1] = 0
            writes.extend(((address, value), (address + 1, 0)))
            # 0x080075d0 sets next=pos+2; type-2 branch never advances it again.

        elif record_type == 0:
            writes, consumed = replay_type_zero(image, logical, pos, low, high)

        else:
            raise DecodeError(f"reserved type-3 record at 0x{pos:x}: 0x{header:04x}")

        records.append(
            {
                "file_offset": pos,
                "flash_address": FLASH_BASE + pos,
                "raw_hex": image[pos : pos + consumed].hex(),
                "decoded_header": header,
                "type": record_type,
                "writes": writes,
            }
        )
        pos += consumed

    raise DecodeError("journal has no erased-word terminator inside second page")


def be_words(data: bytes, offset: int, count: int) -> list[int]:
    return [int.from_bytes(data[offset + item * 2 : offset + item * 2 + 2], "big") for item in range(count)]


def show_words(words: list[int], columns: int) -> str:
    return "\n".join(
        " ".join(f"{word:04x}" for word in words[start : start + columns])
        for start in range(0, len(words), columns)
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("image", type=Path, help="DFU readback binary based at 0x08002000")
    parser.add_argument("--output", type=Path, help="write reconstructed 4096-byte logical EEPROM")
    parser.add_argument("--json", type=Path, help="save record history and decoded tables")
    args = parser.parse_args()

    image = args.image.read_bytes()
    if hashlib.sha256(image).hexdigest() != "5ff18a34b99de0e6ebb657f9f79df8e35a8b8e21459997096c24209bc493262e":
        parser.error("Different dump hash; firmware-specific replay offsets require fresh analysis")
    logical, records, terminator = replay_journal(image)
    type_counts = {kind: sum(record["type"] == kind for record in records) for kind in range(3)}

    print(f"input_sha256={hashlib.sha256(image).hexdigest()}")
    print(f"storage=0x{FLASH_BASE + STORAGE_FILE_OFFSET:08x}..0x{FLASH_BASE + JOURNAL_END - 1:08x}")
    print(f"journal=0x{FLASH_BASE + JOURNAL_FILE_OFFSET:08x}..0x{FLASH_BASE + terminator - 1:08x}")
    print(f"records={len(records)} types={type_counts} terminator_file=0x{terminator:x}")
    print(f"metadata[0x000..0x02d]={logical[:METADATA_SIZE].hex()}")
    print(f"default_layer_mask=eeprom[0x003]=0x{logical[3]:02x}")

    for layer in range(KEYMAP_LAYERS):
        offset = KEYMAP_OFFSET + layer * KEYMAP_LAYER_STRIDE
        print(f"keymap_layer_{layer} eeprom=0x{offset:03x}:")
        print(show_words(be_words(logical, offset, KEYMAP_ROWS * KEYMAP_COLS), KEYMAP_COLS))

    for layer in range(ENCODER_LAYERS):
        offset = ENCODER_OFFSET + layer * ENCODER_LAYER_STRIDE
        print(f"encoder_layer_{layer} eeprom=0x{offset:03x}:")
        print(show_words(be_words(logical, offset, ENCODERS_PER_LAYER * ENCODER_DIRECTIONS), ENCODER_DIRECTIONS))

    nonzero_macros = sum(byte != 0 for byte in logical[MACRO_OFFSET:])
    print(f"macro_nonzero_bytes={nonzero_macros}")
    if args.output:
        args.output.write_bytes(logical)
        print(f"wrote_logical_eeprom={args.output}")
    if args.json:
        args.json.write_text(json.dumps({
            "source_sha256": hashlib.sha256(image).hexdigest(),
            "logical_sha256": hashlib.sha256(logical).hexdigest(),
            "base_snapshot": "Erased physical FF decodes to zero; checksum validity not assumed",
            "records": records, "record_count": len(records), "record_types": type_counts,
            "terminator_file_offset": hex(terminator), "terminator_flash": hex(FLASH_BASE + terminator),
            "metadata_hex": logical[:METADATA_SIZE].hex(), "default_layer_mask": logical[3],
            "keymaps_raw": [[be_words(logical, KEYMAP_OFFSET + layer * KEYMAP_LAYER_STRIDE + row * 12, 6)
                             for row in range(4)] for layer in range(6)],
            "encoder_pairs_raw": [[be_words(logical, ENCODER_OFFSET + layer * ENCODER_LAYER_STRIDE + encoder * 4, 2)
                                   for encoder in range(3)] for layer in range(6)],
            "macro_nonzero_bytes": nonzero_macros,
        }, indent=2) + "\n")


if __name__ == "__main__":
    main()
