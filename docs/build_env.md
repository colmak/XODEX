# Android Build Environment (Authority)

This file defines the **single authoritative environment** for building APK artifacts for `v0.00.x`.

## Frozen toolchain

- Godot Engine: **4.2.2-stable** (Linux/macOS editor + headless CLI)
- Android SDK Platform: **android-34**
- Android Build Tools: **34.0.0**
- Java: **OpenJDK 17**
- OS preference: **Linux/macOS** (Windows supported but not authoritative)

## Policy

- Builds for `v0.00.x` must be produced with the versions above.
- If any version changes, update this file and bump release policy in `docs/release_process.md`.
