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

## Signed Packaging

Run:

```bash
ATLAS_CODESIGN_IDENTITY="Developer ID Application: <Name> (<TEAMID>)" \
ATLAS_INSTALLER_SIGN_IDENTITY="Developer ID Installer: <Name> (<TEAMID>)" \
ATLAS_NOTARY_PROFILE="<profile-name>" \
./scripts/atlas/package-native.sh
```

This signs the app bundle, emits `.zip`, `.dmg`, and `.pkg`, submits artifacts for notarization, and staples results when credentials are available.

## Install Verification

After packaging, validate the DMG installation path with:

```bash
KEEP_INSTALLED_APP=1 ./scripts/atlas/verify-dmg-install.sh
```

## Current Repo State

- Internal packaging can now use a stable local app-signing identity instead of ad hoc signing.
- Signed/notarized release artifacts remain blocked only by missing Apple release credentials on this machine.
