#!/usr/bin/env python3
"""Offline extraction of the repeat-validated KM16 Pro application-region readback."""
import argparse
import importlib.util
import json
from pathlib import Path
import struct
import zlib

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("reference_inspector", ROOT / "scripts/analysis/analyze-firmware.py")
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)
EXPECTED = "5ff18a34b99de0e6ebb657f9f79df8e35a8b8e21459997096c24209bc493262e"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dump", type=Path, default=ROOT / "evidence/backups/dfu-backup-20260912T103449Z/km16pro-live-alt2-0x08002000.bin")
    parser.add_argument("--snapshot", type=Path, default=ROOT / "evidence/device-snapshots/20260912T102734.604561Z/device.json")
    parser.add_argument("--output", type=Path, default=ROOT / "build/analysis/live")
    args = parser.parse_args()
    raw = args.dump.read_bytes()
    sha = helper.digest(raw)
    if sha != EXPECTED:
        parser.error("Different readback hash: these recovered offsets need fresh analysis")
    u32 = lambda address: struct.unpack_from("<I", raw, address - helper.BASE)[0]
    suffix_offset = 0xDDB0
    suffix = struct.unpack_from("<HHHH3sBI", raw, suffix_offset)
    crc = zlib.crc32(raw[:suffix_offset + 12]) ^ 0xFFFFFFFF
    if suffix[4:6] != (b"UFD", 16) or suffix[6] != crc:
        parser.error("Embedded application CRC failed")
    snapshot_bytes = args.snapshot.read_bytes()
    device = json.loads(snapshot_bytes)
    descriptors = []
    for interface in device["interfaces"]:
        descriptor = bytes.fromhex(interface["descriptor_hex"])
        offsets = helper.find_all(raw, descriptor)
        descriptors.append({"usage": f"{interface['PrimaryUsagePage']:04x}:{interface['PrimaryUsage']:04x}",
                            "matches_snapshot": bool(offsets), "file_offsets": [hex(i) for i in offsets],
                            "flash_addresses": [hex(helper.BASE + i) for i in offsets],
                            "reports": helper.report_sizes(descriptor)})
    signature = bytes.fromhex("1201000200000040e9284531")
    usb_offset = raw.index(signature)
    result = {
        "source": {"path": str(args.dump), "sha256": sha, "bytes": len(raw),
                   "base": hex(helper.BASE), "inferred_end_exclusive": hex(helper.BASE + len(raw)),
                   "scope": "Application-region readback, excludes first 8 KiB; dfu-util ended with PIPE, not clean completion."},
        "application": {"payload_bytes": suffix_offset, "payload_sha256": helper.digest(raw[:suffix_offset]),
                        "embedded_update_segment_bytes": suffix_offset + 16, "embedded_crc": hex(crc),
                        "embedded_crc_valid": True, "suffix_file_offset": hex(suffix_offset),
                        "initial_sp": hex(u32(helper.BASE)), "reset_vector": hex(u32(helper.BASE + 4)),
                        "vtor": hex(u32(0x08002204)),
                        "data_rom": hex(u32(0x08002214)), "data_ram_start": hex(u32(0x08002218)),
                        "data_ram_end": hex(u32(0x0800221C)), "bss_start": hex(u32(0x08002220)),
                        "bss_end": hex(u32(0x08002224)),
                        "usb_device_descriptor_file_offset": hex(usb_offset),
                        "usb_bcd_device": hex(struct.unpack_from("<H", raw, usb_offset + 12)[0])},
        "normal_mode_snapshot": {"path": str(args.snapshot), "sha256": helper.digest(snapshot_bytes)},
        "hid_descriptor_comparison": descriptors,
        "regions": [
            {"file_start": "0x0", "file_end_exclusive": "0xddb0", "interpretation": "Application code, constants and initialized data"},
            {"file_start": "0xddb0", "file_end_exclusive": "0xddc0", "interpretation": "CRC-valid DFU suffix actually present in readback"},
            {"file_start": "0xddc0", "file_end_exclusive": "0x1c000", "interpretation": "Erased gap", "all_ff": all(v == 255 for v in raw[0xDDC0:0x1C000])},
            {"file_start": "0x1c000", "file_end_exclusive": "0x1e000", "interpretation": "Candidate physical EEPROM backing, decoded separately from actual firmware"},
        ],
    }
    args.output.mkdir(parents=True, exist_ok=True)
    derived = args.output / "derived"
    derived.mkdir(exist_ok=True)
    for name, data in {"live-application.bin": raw[:suffix_offset],
                       "live-application-with-embedded-suffix.bin": raw[:suffix_offset + 16],
                       "live-settings-physical.bin": raw[0x1C000:0x1E000]}.items():
        dest = derived / name
        if dest.exists() and dest.read_bytes() != data:
            parser.error(f"Refusing to replace differing derivative {dest}")
        dest.write_bytes(data)
    (args.output / "analysis.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({"source_sha256": sha, "application_crc_valid": True,
                      "all_four_descriptors_match_board": all(x["matches_snapshot"] for x in descriptors),
                      "application_bytes": suffix_offset}, indent=2))


if __name__ == "__main__":
    main()
