#!/usr/bin/env python3
"""Reproduce static extraction for the supplied reference image; never opens HID.

Offsets are build-specific. A hash guard prevents applying them to another image.
The device snapshot remains authoritative for the connected board.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import struct
import zlib

ROOT = Path(__file__).resolve().parents[2]
EXPECTED = "d162ee27c2ac752278e6b71e6ebceb8bd74107be84fca1f14d7499792a07e351"
BASE = 0x08002000


def digest(data):
    return hashlib.sha256(data).hexdigest()


def report_sizes(descriptor):
    """Decode HID short items, tracking global push/pop and report IDs."""
    state = {"size": 0, "count": 0, "id": 0}
    stack, bits = [], {}
    pos = 0
    while pos < len(descriptor):
        prefix = descriptor[pos]
        pos += 1
        if prefix == 0xFE:
            if pos + 2 > len(descriptor):
                raise ValueError("truncated HID long-item header")
            length = descriptor[pos]
            end = pos + 2 + length
            if end > len(descriptor):
                raise ValueError("truncated HID long item")
            pos = end
            continue
        length = (0, 1, 2, 4)[prefix & 3]
        end = pos + length
        if end > len(descriptor):
            raise ValueError("truncated HID short item")
        value = int.from_bytes(descriptor[pos:end], "little")
        pos = end
        kind, tag = (prefix >> 2) & 3, prefix >> 4
        if kind == 1:
            if tag in (7, 8, 9):
                state[{7: "size", 8: "id", 9: "count"}[tag]] = value
            elif tag == 10:
                stack.append(state.copy())
            elif tag == 11:
                if not stack:
                    raise ValueError("HID global-state pop without matching push")
                state = stack.pop()
        elif kind == 0 and tag in (8, 9, 11):
            key = ({8: "input", 9: "output", 11: "feature"}[tag], state["id"])
            bits[key] = bits.get(key, 0) + state["size"] * state["count"]
    return [{"type": kind, "id": rid, "payload_bits": count,
             "bytes_including_id": (count + 7) // 8 + bool(rid)}
             for (kind, rid), count in sorted(bits.items())]


def find_all(data, needle):
    """Return every byte offset of a non-empty needle, including overlaps."""
    if not needle:
        raise ValueError("search needle must not be empty")
    pattern = re.compile(b"(?=" + re.escape(needle) + b")")
    return [match.start() for match in pattern.finditer(data)]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--firmware", type=Path,
                        help="reference image (defaults to the sole firmware/vendor/*.bin)")
    parser.add_argument("--definition", type=Path,
                        help="VIA definition (defaults to the sole firmware/vendor/*.json)")
    parser.add_argument("--snapshot", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    for name, pattern in (("firmware", "*.bin"), ("definition", "*.json")):
        if getattr(args, name) is not None:
            continue
        candidates = sorted((ROOT / "firmware/vendor").glob(pattern))
        if len(candidates) != 1:
            parser.error(f"--{name} is required when firmware/vendor/{pattern} "
                         f"has {len(candidates)} matches; supply the input path explicitly")
        setattr(args, name, candidates[0])
    try:
        binary = args.firmware.read_bytes()
        definition_bytes = args.definition.read_bytes()
        snapshot_bytes = args.snapshot.read_bytes()
    except OSError as error:
        parser.error(f"Could not read analysis input: {error}")
    binary_digest = digest(binary)
    if binary_digest != EXPECTED:
        parser.error("Unsupported image hash: fixed-offset extraction is specific to the supplied V0101 image")
    definition = json.loads(definition_bytes)
    device = json.loads(snapshot_bytes)
    bcd_device, pid, vid, dfu, signature, length, crc = struct.unpack("<HHHH3sBI", binary[-16:])
    computed_crc = zlib.crc32(binary[:-4]) ^ 0xFFFFFFFF
    if (signature, length, crc) != (b"UFD", 16, computed_crc):
        parser.error("Invalid DFU suffix")
    payload = binary[:-16]
    u32 = lambda address: struct.unpack_from("<I", payload, address - BASE)[0]
    key_ptr, enc_ptr = u32(0x08004CAC), u32(0x08004CD4)
    keys = struct.unpack_from("<144H", payload, key_ptr - BASE)
    encoders = struct.unpack_from("<36H", payload, enc_ptr - BASE)
    descriptors = []
    for page, usage, offset, size in [(1, 6, 0xD8FB, 68), (1, 2, 0xD98F, 182),
                                     (0xFF60, 0x61, 0xD96D, 34), (0xFF31, 0x74, 0xD8D4, 21)]:
        reference = payload[offset:offset + size]
        matches = [i for i in device["interfaces"]
                   if (i["PrimaryUsagePage"], i["PrimaryUsage"]) == (page, usage)]
        live = bytes.fromhex(matches[0]["descriptor_hex"]) if len(matches) == 1 else None
        descriptors.append({
            "usage": f"{page:04x}:{usage:04x}", "reference_file_offset": hex(offset),
            "reference_flash_address": hex(BASE + offset), "reference_hex": reference.hex(),
            "reference_reports": report_sizes(reference),
            "board_descriptor_available": live is not None,
            "equals_board": reference == live if live is not None else None,
            "board_reports": report_sizes(live) if live is not None else None,
            "differing_bytes": [i for i in range(min(len(reference), len(live)))
                                if reference[i] != live[i]] if live is not None else None,
        })
    layout = []
    for row in definition["layouts"]["keymap"]:
        for entry in row:
            if isinstance(entry, str):
                parts = entry.split("\n")
                layout.append({"matrix": [int(v) for v in parts[0].split(",")],
                               "encoder": parts[-1] if parts[-1].startswith("e") else None})
    result = {
        "authority": "Connected-board snapshot and captured behaviour lead; image findings apply only to the supplied reference build.",
        "inputs": {"firmware": {"path": str(args.firmware), "bytes": len(binary), "sha256": binary_digest},
                   "definition": {"path": str(args.definition), "sha256": digest(definition_bytes)},
                   "board_snapshot": {"path": str(args.snapshot), "sha256": digest(snapshot_bytes)}},
        "board_usb": device["usb"],
        "reference_image": {
            "payload_bytes": len(payload), "payload_sha256": digest(payload),
            "base_address": hex(BASE), "end_exclusive": hex(BASE + len(payload)),
            "initial_sp": hex(u32(BASE)), "reset_vector_with_thumb_bit": hex(u32(BASE + 4)),
            "usb_device_descriptor_offset": "0xd8e9",
            "usb_vid": hex(struct.unpack_from("<H", payload, 0xD8F1)[0]),
            "usb_pid": hex(struct.unpack_from("<H", payload, 0xD8F3)[0]),
            "usb_bcd_device": hex(struct.unpack_from("<H", payload, 0xD8F5)[0]),
            "dfu_suffix": {"bcdDevice": hex(bcd_device), "pid": hex(pid), "vid": hex(vid),
                           "bcdDFU": hex(dfu), "length": length, "crc": hex(crc), "crc_valid": True},
            "factory_keymap_address": hex(key_ptr),
            "factory_keymap_raw_hex": [[[f"0x{keys[l * 24 + r * 6 + c]:04x}" for c in range(6)]
                                         for r in range(4)] for l in range(6)],
            "factory_encoder_address": hex(enc_ptr),
            "factory_encoder_pairs_stored_order": [[[f"0x{encoders[l * 6 + e * 2 + d]:04x}" for d in range(2)]
                                                      for e in range(3)] for l in range(6)],
            "encoder_order_note": "Getter indexes (direction_boolean XOR 1); layer-0 first/second values match observed CW/CCW. Not a live configuration read.",
        },
        "descriptor_comparison": descriptors,
        "definition": {"matrix": definition["matrix"], "physical_layout": layout,
                       "custom_keycodes": definition["customKeycodes"],
                       "is_current_keymap_backup": False},
    }
    args.output.mkdir(parents=True, exist_ok=True)
    (args.output / "analysis.json").write_text(json.dumps(result, indent=2) + "\n")
    (args.output / "derived").mkdir(exist_ok=True)
    derived = args.output / "derived" / "km16pro-application.bin"
    if derived.exists() and derived.read_bytes() != payload:
        parser.error("Existing derivative differs; refusing to overwrite")
    derived.write_bytes(payload)
    print(json.dumps({"analysis": str(args.output / "analysis.json"), "crc_valid": True,
                      "payload_bytes": len(payload),
                      "descriptor_matches": {d["usage"]: d["equals_board"] for d in descriptors}}, indent=2))


if __name__ == "__main__":
    main()
