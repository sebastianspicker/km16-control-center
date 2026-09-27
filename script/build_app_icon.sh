#!/bin/bash
set -euo pipefail

KM16_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KM16_ASSETS="$KM16_ROOT/packaging"
KM16_ICONSET="$KM16_ROOT/build/AppIcon.iconset"
mkdir -p "$KM16_ICONSET"

for size in 16 32 128 256 512; do
  sips --resampleHeightWidth "$size" "$size" "$KM16_ASSETS/AppIcon.png" \
    --out "$KM16_ICONSET/icon_${size}x${size}.png" >/dev/null
  sips --resampleHeightWidth "$((size * 2))" "$((size * 2))" "$KM16_ASSETS/AppIcon.png" \
    --out "$KM16_ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done

# ICNS stores each PNG unchanged in a typed, length-prefixed resource.
python3 - "$KM16_ICONSET" "$KM16_ASSETS/AppIcon.icns" <<'PY'
from pathlib import Path
import struct
import sys

iconset, output = map(Path, sys.argv[1:])
resources = []
for size, standard, retina in (
    (16, b"icp4", b"ic11"), (32, b"icp5", b"ic12"),
    (128, b"ic07", b"ic13"), (256, b"ic08", b"ic14"),
    (512, b"ic09", b"ic10"),
):
    for suffix, kind in (("", standard), ("@2x", retina)):
        png = (iconset / f"icon_{size}x{size}{suffix}.png").read_bytes()
        resources.append(struct.pack(">4sI", kind, len(png) + 8) + png)
body = b"".join(resources)
output.write_bytes(struct.pack(">4sI", b"icns", len(body) + 8) + body)
PY
echo "$KM16_ASSETS/AppIcon.icns"
