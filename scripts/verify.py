#!/usr/bin/env python3
"""Verify local artifacts without device I/O."""
import hashlib
import json
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parents[1]
tool = root / "bin/hid-capture"
for args in [[], ["xx", "3145", "ff60", "61", "1"],
             ["28e9", "3145", "ff60", "61", "0"],
             ["28e9", "3145", "ff60", "61", "3601"],
             ["10000", "3145", "ff60", "61", "1"],
             ["28e9", "3145", "ff60", "61", "-1"]]:
    result = subprocess.run([str(tool), *args], capture_output=True)
    if result.returncode != 2:
        raise SystemExit(f"Argument validation failed: {args}: {result.returncode}")
snapshots = list((root / "evidence/device-snapshots").glob("*/device.json"))
if not snapshots:
    raise SystemExit("No saved device snapshots")
count = 0
for path in snapshots:
    manifest = json.loads(path.read_text())
    for name, expected in json.loads(path.with_name("sha256.json").read_text()).items():
        if Path(name).name != name:
            raise SystemExit(f"Unsafe manifest filename: {name}")
        if hashlib.sha256((path.parent / name).read_bytes()).hexdigest() != expected:
            raise SystemExit(f"Hash mismatch: {path.parent / name}")
    for interface in manifest["interfaces"]:
        data = (path.parent / interface["descriptor_file"]).read_bytes()
        if data.hex() != interface["descriptor_hex"]:
            raise SystemExit("Descriptor hex mismatch")
        if hashlib.sha256(data).hexdigest() != interface["descriptor_sha256"]:
            raise SystemExit("Descriptor SHA-256 mismatch")
        count += 1
print(f"PASS: 6 CLI validation cases; {len(snapshots)} snapshot(s), {count} descriptor(s) verified")
