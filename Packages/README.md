# Packages

This directory contains shared Swift packages planned for Atlas for Mac.

## Current Layout

- `Package.swift` wires the shared domain, protocol, application, infrastructure, adapters, and feature libraries.
- Each package keeps sources under `Sources/<ModuleName>/`.
- Contract-style tests live next to the modules they validate.
