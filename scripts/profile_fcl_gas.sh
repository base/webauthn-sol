#!/usr/bin/env bash
# Profile FCL gas for WebAuthn verification across generated vectors and
# emit a CSV with per-index gas plus a summary of the max-gas case.
#
# Inputs:
#   - test/fixtures/fcl_vectors.json (produced by generate_p256_vectors.py)
#   - Optional env: START, LIMIT to bound the index range
# Behavior:
#   - Forces FCL path in tests; parses forge output; records only valid cases
#   - Uses --via-ir to avoid "stack too deep" during compilation
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
REPO_ROOT="${SCRIPT_DIR}/.."
cd "${REPO_ROOT}"

# Resolve a usable forge binary (PATH first, then default Foundry install).
FORGE_BIN="$(command -v forge || true)"
if [ -z "$FORGE_BIN" ] && [ -x "$HOME/.foundry/bin/forge" ]; then
  FORGE_BIN="$HOME/.foundry/bin/forge"
fi
if [ -z "$FORGE_BIN" ]; then
  echo "forge not found" >&2; exit 1
fi

IN_JSON="test/fixtures/fcl_vectors.json"
OUT_CSV="test/fixtures/fcl_gas_profile.csv"

# Determine the sweep range from the input JSON and optional bounds.
COUNT=$(jq -r .count "$IN_JSON")
START="${START:-0}"
LIMIT="${LIMIT:-$COUNT}"
END=$(( START + LIMIT ))
if [ $END -gt $COUNT ]; then END=$COUNT; fi

echo "index,gas,msgHash,r,s,x,y" > "$OUT_CSV"
# Track the highest measured gas and its corresponding CSV line for reporting.
MAX_GAS=0; MAX_IDX=-1; MAX_LINE=

for ((i=START; i<END; i++)); do
  # Run the single-index profiler test. It logs structured lines we parse below.
  OUT=$(NO_COLOR=1 INDEX=$i "$FORGE_BIN" test --match-test test_profileIndex --via-ir -vvv 2>&1 || true)

  # Extract the validity flag and gas/fields from the test output.
  OK=$(echo "$OUT" | awk '/^  OK:/{getline;print $1}')
  GAS=$(echo "$OUT" | awk '/^  GAS:/{getline;print $1}')
  MH=$(echo "$OUT" | awk '/^  MSGHASH:/{getline;print $1}')
  R=$(echo "$OUT" | awk '/^  R:/{getline;print $1}')
  S=$(echo "$OUT" | awk '/^  S:/{getline;print $1}')
  X=$(echo "$OUT" | awk '/^  X:/{getline;print $1}')
  Y=$(echo "$OUT" | awk '/^  Y:/{getline;print $1}')

  # Only record valid cases (OK=1) with a parsed gas value.
  if [ "${OK:-0}" = "1" ] && [ -n "${GAS:-}" ]; then
    echo "$i,$GAS,$MH,$R,$S,$X,$Y" >> "$OUT_CSV"
    if [ "$GAS" -gt "$MAX_GAS" ]; then MAX_GAS=$GAS; MAX_IDX=$i; MAX_LINE="$i,$GAS,$MH,$R,$S,$X,$Y"; fi
  fi

  # Progress heartbeat every 50 iterations.
  if (( (i-START+1) % 50 == 0 )); then echo "Processed $((i-START+1))/$((END-START))"; fi
done

echo "CSV written: $OUT_CSV"
echo "Max gas: $MAX_GAS at index $MAX_IDX"
echo "Max line: $MAX_LINE"
