# ADR-004: Helper Executable and Native Packaging Pipeline

## Status

Accepted

## Context

Atlas for Mac needed to move beyond a print-only helper stub and legacy CLI release workflows. The MVP required a structured helper execution path for destructive actions plus a native build/package pipeline that could produce a distributable macOS app bundle.

## Decision

- Implement the helper as a JSON-driven executable that validates allowlisted target paths before acting.
- Invoke the helper from the worker through a structured client rather than direct UI mutations.
- Build the app with `xcodegen + xcodebuild`, embed the helper binary into `Contents/Helpers/`, then emit `.zip`, `.dmg`, and `.pkg` distribution artifacts during packaging.
- Add a native GitHub Actions workflow that packages the app artifact and can optionally extend to signing/notarization when release credentials are available.

## Consequences

- The worker/helper boundary is now implemented as code, not just documentation.
- Local and CI environments can produce a real `.app` bundle, `.zip`, `.dmg`, and `.pkg` installer artifacts for MVP verification, with DMG installation validated into the user Applications folder.
- The helper is still not a fully blessed privileged service, so future release hardening may deepen this path.
- Packaging now depends on Xcode project generation remaining synchronized with `project.yml`.

## Alternatives Considered

- Keep the helper as a stub — rejected because uninstall and destructive flows would remain architecturally incomplete.
- Bundle no helper and let the worker mutate files directly — rejected because it weakens privilege boundaries.
- Delay native packaging until release week — rejected because it postpones critical integration risk discovery.
