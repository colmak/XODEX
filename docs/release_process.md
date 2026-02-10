# Android Release Process

## Keystore policy

- Use a **release keystore** for distributable APKs.
- Keystore file must be stored **outside the Git repository**.
- Local path is maintained by release maintainers (not committed).
- Configure `keystore/release`, `keystore/release_user`, and `keystore/release_password` in the local export preset before non-debug release builds.

## Build process

1. Confirm build authority versions in `docs/build_env.md`.
2. Run `./scripts/build_apk.sh`.
3. Validate install on device with `adb install builds/v0.00.1/BurzenTD_v0.00.1.apk`.
4. Record the checksum in `docs/releases/v0.00.1.md`.
5. Create a `v0.00.1` Git tag and GitHub Release.
6. Attach APK and checksum, include install instructions.

## Notes

- `./scripts/build_apk.sh --dry-run` is the required preflight for CI/local validation.
- APK artifacts belong under `builds/<version>/`.
