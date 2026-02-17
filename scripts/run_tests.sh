#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

python3 -m unittest -v simulation.test_thermal_reference simulation.test_basic_mechanics simulation.test_tower_wave_settings
./scripts/build_apk.sh --dry-run
