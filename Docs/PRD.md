# PRD

## Product

- Working name: `Atlas for Mac`
- Category: `Mac Maintenance Workspace`
- Target platform: `macOS`

## Positioning

Atlas for Mac is a native desktop maintenance application that helps users understand why their Mac is slow, full, or disorganized, then take safe and explainable action.

## Product Goals

- Help users complete a safe space-recovery decision in minutes.
- Turn scanning into an explainable action plan.
- Unify cleanup, uninstall, permissions, history, and recovery into one workflow.
- Prefer reversible actions over permanent deletion.
- Support heavy Mac users and developer-oriented cleanup scenarios.

## Non-Goals

- No anti-malware suite in MVP.
- No Mac App Store release in MVP.
- No full automation rule engine in MVP.
- No advanced storage treemap in MVP.
- No menu bar utility in MVP.

## Target Users

- Heavy Mac users with persistent disk pressure.
- Developers with Xcode, simulators, containers, package-manager caches, and build artifacts.
- Creative users with large local media libraries.
- Cautious mainstream users who want safer maintenance than terminal tools.

## MVP Modules

- `Overview`
- `Smart Clean`
- `Apps`
- `History`
- `Recovery`
- `Permissions`
- `Settings`

## Core Differentiators

- Explainable cleanup recommendations
- Recovery-first execution model
- Unified maintenance workflow
- Developer-aware cleanup coverage
- Least-privilege permission design

## Success Metrics

- First scan completion rate
- Scan-to-execution conversion rate
- Permission completion rate
- Recovery success rate
- Task success rate
- User-visible space reclaimed

## MVP Acceptance Summary

- Users can run a scan without granting all permissions up front.
- Findings are grouped by risk and explained before execution.
- Users can preview app uninstall footprint before removal.
- Every destructive task produces a history record.
- Recoverable actions expose a restoration path.
- The app includes a visible open-source acknowledgement and third-party notices page.
