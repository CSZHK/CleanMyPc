# Atlas for Mac Docs

This directory contains the working product, design, engineering, and compliance documents for the Atlas for Mac desktop application.

## Principles

- Atlas for Mac is an independent product.
- The project does not use the Mole brand in user-facing naming.
- The project may reuse or adapt parts of the upstream Mole codebase under the MIT License.
- User-facing flows should prefer explainability, reversibility, and least privilege.

## Document Map

- `PRD.md` — product requirements and MVP scope
- `IA.md` — information architecture and navigation model
- `Architecture.md` — application architecture and process boundaries
- `Protocol.md` — local JSON protocol and core schemas
- `TaskStateMachine.md` — task lifecycle rules
- `ErrorCodes.md` — user-facing and system error registry
- `ROADMAP.md` — active internal-beta hardening roadmap and conditional release branch
- `Backlog.md` — epics, issue seeds, and board conventions
- `DECISIONS.md` — frozen product and architecture decisions
- `RISKS.md` — active project risk register
- `Execution/` — weekly execution plans, status snapshots, beta checklists, gate reviews, manual test SOPs, and release execution notes
- `Execution/Current-Status-2026-03-07.md` — current engineering status snapshot
- `Execution/Release-Roadmap-2026-03-12.md` — internal-beta hardening plan plus conditional signed release path
- `Execution/UI-Audit-2026-03-08.md` — UI design audit and prioritized remediation directions
- `Execution/UI-Copy-Walkthrough-2026-03-09.md` — page-by-page UI copy glossary, consistency checklist, and acceptance guide
- `Execution/Execution-Chain-Audit-2026-03-09.md` — end-to-end review of real vs scaffold execution paths and release-facing trust gaps
- `Execution/Implementation-Plan-ATL-201-202-205-2026-03-12.md` — implementation plan for internal-beta hardening tasks ATL-201, ATL-202, and ATL-205
- `Execution/Smart-Clean-Execution-Coverage-2026-03-09.md` — user-facing summary of what Smart Clean can execute for real today
- `Execution/Smart-Clean-QA-Checklist-2026-03-09.md` — QA checklist for scan, execute, rescan, and physical restore validation
- `Execution/Smart-Clean-Manual-Verification-2026-03-09.md` — local-machine fixture workflow for validating real Smart Clean execution and restore
- `Templates/` — issue, epic, ADR, gate, and handoff templates
- `WORKSPACE_LAYOUT.md` — planned repository and module structure
- `HELP_CENTER_OUTLINE.md` — help center structure
- `COPY_GUIDELINES.md` — product voice and UI copy rules
- `ATTRIBUTION.md` — upstream acknowledgement strategy
- `THIRD_PARTY_NOTICES.md` — third-party notices and license references
- `ADR/` — architecture decision records
- `Sequence/` — flow-level engineering sequence documents

## Ownership

- Product decisions: `Product Agent`
- Interaction and content design: `UX Agent`
- App implementation: `Mac App Agent`
- Protocol and domain model: `Core Agent`
- XPC and privileged integration: `System Agent`
- Upstream adaptation: `Adapter Agent`
- Verification: `QA Agent`
- Distribution and release: `Release Agent`
- Compliance and docs: `Docs Agent`

## Update Rules

- Update `PRD.md` before changing MVP scope.
- Update `Protocol.md` and `TaskStateMachine.md` together when task lifecycle or schema changes.
- Add or update an ADR for any process-boundary, privilege, or storage decision.
- Keep `ATTRIBUTION.md` and `THIRD_PARTY_NOTICES.md` in sync with shipped code.
