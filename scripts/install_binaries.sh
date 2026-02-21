#!/usr/bin/env bash
set -euo pipefail

if [ "${EUID}" -ne 0 ]; then
  SUDO="sudo"
else
  SUDO=""
fi

require_cmd() {
  local cmd="$1"
  local hint="$2"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: required command '$cmd' is missing (${hint})." >&2
    exit 1
  fi
}

install_godot() {
  if command -v godot4 >/dev/null 2>&1 || command -v godot >/dev/null 2>&1; then
    echo "Godot binary already available; skipping install."
    return
  fi

  echo "Installing Godot runtime (godot4) from apt repositories..."
  $SUDO apt-get update
  $SUDO apt-get install -y godot4

  if ! command -v godot4 >/dev/null 2>&1; then
    echo "Error: godot4 was not found after install." >&2
    exit 1
  fi

  if ! command -v godot >/dev/null 2>&1; then
    local target
    target="$(command -v godot4)"
    if [ -n "$target" ]; then
      echo "Creating /usr/local/bin/godot symlink -> $target"
      $SUDO ln -sf "$target" /usr/local/bin/godot
    fi
  fi
}

require_cmd apt-get "Debian/Ubuntu package manager"
install_godot

echo "Installed binary versions:"
if command -v godot4 >/dev/null 2>&1; then
  godot4 --version || true
fi
if command -v godot >/dev/null 2>&1; then
  godot --version || true
fi
