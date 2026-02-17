# Contributing to BURZEN Tower Defense (XODEX)

Thanks for helping improve the prototype. This project is currently optimized for rapid iteration on Android-first gameplay systems (thermal combat, seeded procedural runs, and WASMUTABLE events).

## Quick start

1. Fork/clone the repository.
2. Run checks:
   ```bash
   ./scripts/run_tests.sh
   ```
3. Keep commits focused and traceable to one gameplay/documentation concern.

## Branch naming

Use one of these prefixes:

- `fix/<area>-<short-description>`
- `feature/<area>-<short-description>`
- `docs/<area>-<short-description>`
- `chore/<area>-<short-description>`
- `stabilization/<area>-<yyyy>`

Examples:

- `feature/thermal-decay-controls`
- `fix/android-export-keystore-check`
- `docs/wasmutable-extension-guide`

## Commit style

Use imperative, scope-first messages:

- `fix(simulation): clamp tower heat before overheat trigger`
- `feat(ui): add overlay cycle indicator label`
- `docs(contrib): add tower extension walkthrough`

Recommended format:

```
<type>(<scope>): <summary>

Optional detail bullet(s) explaining why and impact.
```

## Pull request checklist

Before opening a PR, verify:

- [ ] Branch follows naming convention.
- [ ] `./scripts/run_tests.sh` passes locally.
- [ ] Relevant docs are updated (`README.md`, `docs/` specs).
- [ ] Generated artifacts remain untracked (`simulation/logs/*`, APK/AAB outputs, local keystores) unless intentionally release-staged.
- [ ] Changes are tested on target platform if applicable (Android or desktop simulation).
- [ ] Any balancing changes include rationale and sample before/after values.
- [ ] Screenshots/video attached for UX-visible changes.

## Architecture extension quick references

See `docs/extensibility_guide.md` for step-by-step additions:

- New tower type
- New enemy class
- New WASMUTABLE event rule

## Reporting bugs and balance issues

Use the issue templates under `.github/ISSUE_TEMPLATE/`:

- Bug report
- Feature request
- Balance tuning report
