# Beta Gate Review

## Gate

- `Beta Candidate`

## Review Date

- `2026-03-07`

## Scope Reviewed

- `Overview`
- `Smart Clean`
- `Apps`
- `History`
- `Recovery`
- `Permissions`
- `Settings`
- native packaging and install flow
- native UI smoke coverage
- Chinese-first app-language switching and localized shell copy

## Readiness Checklist

- [x] Required P0 tasks complete
- [x] Docs updated
- [x] Risks reviewed
- [x] Open questions below threshold for internal beta
- [x] Next-stage inputs available

## Evidence Reviewed

- `Docs/Execution/MVP-Acceptance-Matrix.md`
- `Docs/Execution/Beta-Acceptance-Checklist.md`
- `Docs/Execution/Manual-Test-SOP.md`
- `scripts/atlas/full-acceptance.sh`
- `scripts/atlas/run-ui-automation.sh`
- `scripts/atlas/signing-preflight.sh`

## Automated Validation Summary

- `swift test --package-path Packages` — pass
- `swift test --package-path Apps` — pass
- `./scripts/atlas/full-acceptance.sh` — pass
- `./scripts/atlas/run-ui-automation.sh` — pass on a machine with Accessibility trust (`4` UI tests, including language switching)
- `./scripts/atlas/verify-dmg-install.sh` — pass
- `./scripts/atlas/verify-app-launch.sh` — pass
- `./scripts/atlas/package-native.sh` — pass

## Beta Assessment

### Product Functionality

- Core frozen MVP workflows are complete end to end.
- Recovery-first behavior is visible in both Smart Clean and Apps flows.
- Settings and permission refresh flows are functional.
- The app now defaults to `简体中文` and supports switching to `English` through persisted settings.

### Packaging and Installability

- `.app`, `.zip`, `.dmg`, and `.pkg` artifacts are produced successfully.
- Native packaging has been rerun successfully after the localization work.
- DMG installation into `~/Applications/Atlas for Mac.app` is validated.
- Installed app launch is validated.

### Test Coverage

- Shared package tests are green.
- App-layer tests are green.
- Native UI smoke is green on a machine with Accessibility trust.
- Manual beta checklist and SOP are now present for human validation.

## Blockers

- Public signed/notarized distribution is still blocked by missing Apple release credentials:
  - `Developer ID Application`
  - `Developer ID Installer`
  - `ATLAS_NOTARY_PROFILE`

## Decision

- `Pass with Conditions`

## Conditions

- Internal beta / trusted-user beta can proceed with the current ad hoc-signed local artifacts.
- Public beta or broad external distribution must wait until signing and notarization credentials are available and the release packaging path is re-run.

## Follow-up Actions

- Obtain Apple signing and notarization credentials.
- Re-run `./scripts/atlas/signing-preflight.sh`.
- Re-run `./scripts/atlas/package-native.sh` with signing/notarization environment variables.
- Validate signed DMG / PKG install behavior on a clean machine.
