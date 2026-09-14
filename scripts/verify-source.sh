#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export PYTHONDONTWRITEBYTECODE=1

# Public source checks: no original firmware, saved captures, or connected device required.
bash scripts/build.sh
node --test tests/webhid-trace.test.cjs
python3 -m unittest discover -s tests -p 'test_*.py' -v
node --check site/app.js
python3 scripts/build-site.py
cmake -S firmware/custom -B build/custom -DCMAKE_BUILD_TYPE=Debug
cmake --build build/custom
ctest --test-dir build/custom --output-on-failure
bash scripts/verify-companion.sh
swift test --package-path apps/KM16ControlCenter
