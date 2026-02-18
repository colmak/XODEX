#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLI="$SCRIPT_DIR/burzen_td_cli.py"

run_sequence() {
  local input="$1"
  printf "%b" "$input" | python "$CLI"
}

OUT1="$(run_sequence "place_tower polar_hydrator 5 10\nstart_wave\nsim_step\nquery_state\n")"
LAST1="$(printf '%s\n' "$OUT1" | tail -n 1)"

printf '%s' "$LAST1" | python -c 'import json,sys; d=json.loads(sys.stdin.read());
assert d["numeric_measures"]["wave"]==1
assert d["numeric_measures"]["cash"]==88
assert d["numeric_measures"]["global_heat"]>=0
assert len(d["numeric_measures"]["tower_details"])==1
print("scenario1_ok")'

OUT2="$(run_sequence "sim_step\n")"
printf '%s\n' "$OUT2" | tail -n 1 | python -c 'import json,sys; d=json.loads(sys.stdin.read()); assert d["error"]=="no wave"; print("scenario2_ok")'

echo "All CLI regression checks passed."
