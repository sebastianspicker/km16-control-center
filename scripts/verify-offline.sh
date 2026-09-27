#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export PYTHONDONTWRITEBYTECODE=1

python3 scripts/verify-preservation.py
scripts/build.sh
python3 scripts/verify.py
node --test scripts/tests/webhid-trace.test.cjs
python3 -m unittest discover -s scripts/tests -p 'test_*.py' -v

python3 scripts/analysis/analyze-live-firmware.py
python3 scripts/analysis/analyze-firmware.py \
  --snapshot evidence/device-snapshots/20260912T102734.604561Z/device.json \
  --output build/analysis/reference
python3 scripts/analysis/decode-live-eeprom.py \
  evidence/backups/dfu-backup-20260912T103449Z/km16pro-live-alt2-0x08002000.bin \
  --output build/analysis/live/logical-eeprom.bin \
  --json build/analysis/live/settings.json > build/analysis/live/settings-decoder.log
python3 scripts/analysis/extract-hardware-contract.py

cmake -S firmware/custom -B build/custom -DCMAKE_BUILD_TYPE=Debug
cmake --build build/custom
ctest --test-dir build/custom --output-on-failure
build/custom/km16_custom_demo
cmake --build build/custom --target cortex-m3-objects
bash scripts/verify-companion.sh
python3 scripts/verify-preservation.py
