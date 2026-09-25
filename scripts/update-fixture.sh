#!/usr/bin/env bash
# Replace the vendored parity fixture with the one sector_momentum publishes.
# Run after a rule or horizon preset changes upstream, then `swift test` and
# commit: if the Swift rules no longer match, the tests say which case.
set -euo pipefail
cd "$(dirname "$0")/.."
curl -fsSL https://jbarte.github.io/sector_momentum/band-fixture.json \
  -o Tests/MomentumKitTests/Fixtures/band-fixture.json
echo "Updated. Now: swift test"
