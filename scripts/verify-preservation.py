#!/usr/bin/env python3
"""Verify every pre-organization file against its preserved bytes; no device I/O."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ledger = json.loads((ROOT / "evidence/organization/relocation.json").read_text())
failures = []
for old, record in ledger["files"].items():
    relative = record["historical_copy"] or record["current_path"]
    path = ROOT / relative
    if not path.is_file():
        failures.append(f"Missing preserved file: {old} -> {relative}")
        continue
    data = path.read_bytes()
    if len(data) != record["bytes"] or hashlib.sha256(data).hexdigest() != record["sha256"]:
        failures.append(f"Preserved bytes differ: {old} -> {relative}")
if failures:
    raise SystemExit("\n".join(failures))
print(f"PASS: {len(ledger['files'])} pre-organization files preserved byte-for-byte")
