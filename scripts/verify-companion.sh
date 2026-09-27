#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build
swift build --target KM16ControlCoreTests
swift run KM16ControlCoreSelfTest
swift run KM16ControlCenter --store-self-test
if [[ -f evidence/captures/knob-mapping-summary.json ]]; then
  swift run KM16IntegrationSelfTest --capture-root evidence/captures
else
  swift run KM16IntegrationSelfTest
fi
python3 scripts/verify-preset-assets.py
echo "Companion core, store, protocol, replay and process-fixture checks passed. No GUI input, device access or live Codex session was used."
