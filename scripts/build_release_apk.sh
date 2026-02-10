#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_DIR="$ROOT_DIR/android/BurzenTD"
OUTPUT_DIR="$ROOT_DIR/builds/v0.00.1"
OUTPUT_APK="$OUTPUT_DIR/BurzenTD_v0.00.1.apk"

if ! command -v godot4 >/dev/null 2>&1 && ! command -v godot >/dev/null 2>&1; then
  echo "Error: Godot executable not found. Install Godot 4 and retry." >&2
  exit 1
fi

GODOT_BIN="$(command -v godot4 || command -v godot)"

mkdir -p "$OUTPUT_DIR"

"$GODOT_BIN" --headless --path "$PROJECT_DIR" --export-release "Android" "$OUTPUT_APK"

echo "Release APK built at: $OUTPUT_APK"
