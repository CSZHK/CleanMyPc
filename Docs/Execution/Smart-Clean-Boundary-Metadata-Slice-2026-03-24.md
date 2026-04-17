# Smart Clean Boundary Metadata Slice — 2026-03-24

## Goal

Stabilize the `review-only` versus `executable` boundary in Smart Clean so the app model and UI both use the same semantics instead of inferring capability from scattered conditions.

## Scope

This slice adds one centralized derived execution-boundary model for `ActionItem`:

- `direct`
- `helper`
- `reviewOnly`

## Why This Slice

Before this slice:

- Smart Clean UI mainly inferred capability from `kind` plus `targetPaths`
- app-model execution gating used separate logic
- helper-backed actions were not visually differentiated from direct execution in the Smart Clean preview

This slice keeps the existing protocol shape intact and centralizes the capability rules in domain code.

## Rules

- `inspectPermission` and `reviewEvidence` remain `reviewOnly`
- `removeApp` is treated as `helper`
- executable items with protected-path targets are treated as `helper`
- executable items with supported user-owned targets are treated as `direct`
- older cached plans without plan-carried targets must still fall back to finding-carried targets when possible

## User-Facing Outcome

- Smart Clean preview now distinguishes:
  - direct execution
  - helper-backed execution
  - review-only
- AppModel execution gating uses the same boundary semantics while preserving old-plan compatibility.

## Validation

- domain tests verify helper/direct/review-only boundary derivation
- app-model tests verify that older cached plans still execute when finding-carried targets remain available

## Non-Goals

- changing the worker protocol schema
- widening Smart Clean execution support
- changing recovery semantics
