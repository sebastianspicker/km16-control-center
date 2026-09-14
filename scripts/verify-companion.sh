#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build --package-path apps/KM16ControlCenter
swift build --package-path apps/KM16ControlCenter --target KM16ControlCoreTests
swift run --package-path apps/KM16ControlCenter KM16ControlCoreSelfTest
swift run --package-path apps/KM16ControlCenter KM16ControlCenter --store-self-test
if [[ -f evidence/captures/knob-mapping-summary.json ]]; then
  swift run --package-path apps/KM16ControlCenter KM16IntegrationSelfTest --capture-root evidence/captures
else
  swift run --package-path apps/KM16ControlCenter KM16IntegrationSelfTest
fi
python3 scripts/verify-preset-assets.py
echo "Companion core, store, protocol, replay and process-fixture checks passed. No GUI input, device access or live Codex session was used."
