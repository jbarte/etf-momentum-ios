#!/usr/bin/env bash
# Fail if the vendored parity fixture differs from the published one -- i.e. a
# Python rule or preset changed and the Swift port has not been checked
# against it yet. Byte comparison: the published file is deterministic.
set -euo pipefail
cd "$(dirname "$0")/.."
vendored=Tests/MomentumKitTests/Fixtures/band-fixture.json
published=$(mktemp)
trap 'rm -f "$published"' EXIT
curl -fsSL https://jbarte.github.io/sector_momentum/band-fixture.json -o "$published"
if ! cmp -s "$published" "$vendored"; then
  echo "::error::band-fixture.json differs from the published one. Run scripts/update-fixture.sh, then swift test, and commit."
  diff "$published" "$vendored" | head -40 || true
  exit 1
fi
echo "band-fixture.json matches the published one."
