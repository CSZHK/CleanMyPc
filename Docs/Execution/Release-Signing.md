# Release Signing and Notarization

## Goal

Turn Atlas for Mac from an installable local build into a publicly distributable macOS release.

## Required Credentials

- `Developer ID Application` certificate for app signing
- `Developer ID Installer` certificate for installer signing
- `notarytool` keychain profile for notarization

## Environment Variables Used by Packaging

- `ATLAS_CODESIGN_IDENTITY`
- `ATLAS_CODESIGN_KEYCHAIN`
- `ATLAS_INSTALLER_SIGN_IDENTITY`
- `ATLAS_NOTARY_PROFILE`
- `ATLAS_NOTARY_KEYCHAIN` (optional; required when the notary profile lives in a non-default keychain such as CI)

## Stable Local Signing

For local development machines that do not have Apple release certificates yet, provision a stable app-signing identity once:

```bash
./scripts/atlas/ensure-local-signing-identity.sh
```

After that, `./scripts/atlas/package-native.sh` automatically prefers this local identity over ad hoc signing. This keeps the installed app bundle identity stable enough for macOS permission prompts and TCC decisions to behave consistently across rebuilds.

Notes:

- This local identity is only for internal/dev packaging.
- `.pkg` signing and notarization still require Apple `Developer ID Installer` and `notarytool` credentials.
- The local identity is stored in a dedicated keychain at `~/Library/Keychains/AtlasLocalSigning.keychain-db` unless overridden by env vars.

## Preflight

Run:

```bash
./scripts/atlas/signing-preflight.sh
```

If preflight passes, the current machine is ready for signed packaging.

## Version Prep

Before pushing a release tag, align the app version, build number, and changelog skeleton:

```bash
./scripts/atlas/prepare-release.sh 1.0.3
```

Optional arguments:

```bash
./scripts/atlas/prepare-release.sh 1.0.3 4 2026-03-23
```

This updates:

- `project.yml`
- `Apps/AtlasApp/Sources/AtlasApp/AtlasAppModel.swift`
- `CHANGELOG.md`

The script increments `CURRENT_PROJECT_VERSION` automatically when you omit the build number. Review the new changelog section before creating the `V1.0.3` tag.

## Signed Packaging

Run:

```bash
ATLAS_CODESIGN_IDENTITY="Developer ID Application: <Name> (<TEAMID>)" \
ATLAS_INSTALLER_SIGN_IDENTITY="Developer ID Installer: <Name> (<TEAMID>)" \
ATLAS_NOTARY_PROFILE="<profile-name>" \
./scripts/atlas/package-native.sh
```

This signs the app bundle, emits `.zip`, `.dmg`, and `.pkg`, submits artifacts for notarization, and staples results when credentials are available.

If the notary profile is stored in a non-default keychain, also set:

```bash
ATLAS_NOTARY_KEYCHAIN="/path/to/release.keychain-db"
```

## Install Verification

After packaging, validate the DMG installation path with:

```bash
KEEP_INSTALLED_APP=1 ./scripts/atlas/verify-dmg-install.sh
```

## GitHub Tag Release Automation

Tagged pushes matching `V*` now reuse the same packaging flow in CI and attach native release assets to the GitHub Release created by `.github/workflows/release.yml`.

The GitHub Release body is generated from the matching version section in `CHANGELOG.md`, then appends the actual packaging mode note:

- `developer-id` -> signed/notarized packaging note
- `development` -> prerelease fallback note

If a changelog section is missing for the pushed tag version, the workflow falls back to a short placeholder instead of publishing an empty body.

Required GitHub Actions secrets:

- `ATLAS_RELEASE_APP_CERT_P12_BASE64`
- `ATLAS_RELEASE_APP_CERT_P12_PASSWORD`
- `ATLAS_RELEASE_INSTALLER_CERT_P12_BASE64`
- `ATLAS_RELEASE_INSTALLER_CERT_P12_PASSWORD`
- `ATLAS_NOTARY_KEY_ID`
- `ATLAS_NOTARY_ISSUER_ID` for Team API keys; omit only if you intentionally use an Individual API key
- `ATLAS_NOTARY_API_KEY_BASE64`

If those secrets are present, the workflow bootstraps a temporary keychain with `./scripts/atlas/setup-release-signing-ci.sh`, stores a `notarytool` profile there, derives `ATLAS_VERSION` from the pushed tag name, then runs `./scripts/atlas/package-native.sh`.

If those secrets are missing, the workflow automatically falls back to:

- `./scripts/atlas/ensure-local-signing-identity.sh`
- local development signing for the app bundle
- unsigned installer packaging if no installer identity exists
- no notarization
- GitHub Release marked as `prerelease`

Release flow:

```bash
git tag -a V1.0.3 -m "Release V1.0.3"
git push origin V1.0.3
```

That tag creates one GitHub Release containing:

- legacy Go binaries and Homebrew tarballs from the existing release pipeline
- `Atlas-for-Mac.zip`
- `Atlas-for-Mac.dmg`
- `Atlas-for-Mac.pkg`
- native and aggregate SHA-256 checksum files

Packaging mode by credential state:

- `Developer ID secrets present` -> signed and notarized native assets, normal GitHub Release
- `Developer ID secrets missing` -> development-signed native assets, GitHub `prerelease`

## Current Repo State

- Internal packaging can now use a stable local app-signing identity instead of ad hoc signing.
- Signed/notarized release artifacts remain blocked only by missing Apple release credentials on this machine.
- Tagged GitHub Releases can still publish development-mode native assets without those credentials.
