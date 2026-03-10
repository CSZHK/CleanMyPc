# Apps

This directory contains user-facing application targets.

## Current Entry

- `AtlasApp/` hosts the main native macOS shell.
- `Package.swift` exposes the app shell as a SwiftPM executable target for local iteration.
- The app shell now wires fallback health, Smart Clean, app inventory, and helper integrations through the structured worker path.
- Root `project.yml` can regenerate `Atlas.xcodeproj` with `xcodegen generate` for native app packaging and installer production.
