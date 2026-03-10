# Polish Week 1 Plan

## Goal

Establish a shared polish baseline and improve the two most trust-sensitive MVP flows: `Smart Clean` and `Apps`.

## Must Deliver

- MVP state audit covering default, loading, empty, partial-permission, success, and failure states
- Shared polish baseline for spacing, card hierarchy, CTA priority, status tone, and destructive-action language
- `Smart Clean` improvements for scan controls, preview readability, execution confidence, and result continuity
- `Apps` improvements for uninstall preview clarity, leftover visibility, and recovery confidence
- Narrow verification for first-run, scan, preview, execute, uninstall, and restore-adjacent flows

## Day Plan

- `Day 1` Audit all frozen MVP routes and record the missing states and trust gaps
- `Day 2` Tighten shared design-system primitives and copy rules before page-specific tweaks
- `Day 3` Polish `Smart Clean` from scan initiation through preview and execute feedback
- `Day 4` Polish `Apps` from refresh through uninstall preview and completion messaging
- `Day 5` Run focused verification and hold a gate review for Week 2 polish work

## Owner Tasks

- `Product Agent` define the polish scorecard and keep work inside the frozen MVP scope
- `UX Agent` close wording, hierarchy, and permission-guidance gaps in trust-critical surfaces
- `Mac App Agent` implement design-system and feature-level refinements for `Smart Clean` and `Apps`
- `QA Agent` verify the state matrix and catch visual or flow regressions in the primary paths
- `Docs Agent` keep backlog, execution notes, and follow-up risks in sync with the week output

## Exit Criteria

- `Smart Clean` and `Apps` read clearly without requiring implementation knowledge
- Primary CTAs are obvious, secondary actions are quieter, and destructive actions feel reversible
- The top-level screens no longer fall back to generic empty or ambiguous progress states in core flows
- Week 2 can focus on `Overview`, `History`, and `Permissions` without reopening Week 1 trust issues
