#!/usr/bin/env python3
"""Verify exported presets and bundled setup resources against the source catalog."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PRESETS = ROOT / "presets"
BUNDLED = ROOT / "apps/KM16ControlCenter/Sources/KM16ControlCenter/Resources/PresetSetup"
profiles = json.loads((PRESETS / "all.json").read_text())["profiles"]
assert len(profiles) == 16
assert sum(len(profile["bindings"]) for profile in profiles) == 400
for profile in profiles:
    preset_id = profile["presetID"]
    assert json.loads((PRESETS / f"{preset_id}.json").read_text())["profiles"] == [profile]
for source in (PRESETS / "setup").glob("*.md"):
    assert source.read_bytes() == (BUNDLED / source.name).read_bytes(), f"Stale bundled guide: {source.name}"
fragment = PRESETS / "keybindings/git-review.code-keybindings.json"
assert fragment.read_bytes() == (BUNDLED / "keybindings" / fragment.name).read_bytes()
bindings = json.loads(fragment.read_text())
assert len({binding["key"] for binding in bindings}) == len(bindings)
print("PASS: 16 exported presets / 400 assignments and bundled setup files agree.")
