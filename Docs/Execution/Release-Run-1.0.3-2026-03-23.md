# Release Run — 1.0.3 — 2026-03-23

## Goal

Drive `v1.0.3` from release-prepared source state to a pushed release tag and observe whether GitHub publishes a normal release or falls back to a prerelease.

## Task List

- [x] Confirm version bump, changelog, and release notes are prepared in source.
- [x] Rebuild native artifacts and verify the bundled app reports `1.0.3 (4)`.
- [x] Reinstall the local DMG candidate and verify the installed app reports `1.0.3 (4)`.
- [x] Run `./scripts/atlas/full-acceptance.sh` on the release candidate.
- [ ] Clean the worktree by resolving remaining README and screenshot collateral updates.
- [ ] Commit release-collateral updates required for a clean tagging state.
- [ ] Create annotated tag `V1.0.3`.
- [ ] Push `main` and `V1.0.3` to `origin`.
- [ ] Observe the GitHub `release.yml` workflow result.
- [ ] Confirm whether GitHub published a normal release or a prerelease fallback.

## Known Release Gate

- Local signing preflight still reports missing `Developer ID Application`, `Developer ID Installer`, and `ATLAS_NOTARY_PROFILE`.
- GitHub Actions may still produce a formal signed release if the required repository secrets are configured.
- If those secrets are missing, the tag push will publish a development-signed prerelease instead of a formal signed release.
