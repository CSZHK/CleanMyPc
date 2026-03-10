# UI Copy Walkthrough — 2026-03-09

## Goal

This checklist translates the current Atlas UI copy system into a page-by-page review guide so future edits keep the same business meaning, terminology, and user-facing tone.

This document assumes the frozen MVP scope:

- `Overview`
- `Smart Clean`
- `Apps`
- `History`
- `Permissions`
- `Settings`
- supporting surfaces such as `Task Center`, toolbar, command menus, and route labels

## Core Glossary

Use these terms consistently across product UI, docs, QA, and release notes.

- `Scan` — read-only analysis that collects findings. It never changes the system by itself.
- `Cleanup Plan` — the reviewed set of cleanup steps Atlas proposes from current findings.
- `Uninstall Plan` — the reviewed set of uninstall steps Atlas proposes for one app.
- `Review` — the human confirmation step before a plan runs.
- `Run Plan` / `Run Uninstall` — the action that applies a reviewed plan.
- `Estimated Space` / `预计释放空间` — the amount the current plan can free. It may decrease after execution because the plan is rebuilt from remaining items.
- `Recoverable` — Atlas can restore the result while the retention window is still open.
- `App Footprint` — the current disk space an app uses.
- `Leftover Files` — related support files, caches, or launch items shown before uninstall.
- `Limited Mode` — Atlas works with partial permissions and asks for more access only when a specific workflow needs it.

## Global Rules

### Meaning

- Always explain what the user is looking at before suggesting an action.
- Distinguish `current plan` from `remaining items after execution`.
- Use `plan` as the primary noun for actionable work. Avoid relying on `preview` alone when the object is something the user can run.
- If the action opens macOS settings, say `Open System Settings` / `打开系统设置`.

### Tone

- Calm
- Direct
- Reassuring
- Technical only when necessary

### CTA Rules

- Prefer explicit verbs: `Run Scan`, `Update Plan`, `Run Plan`, `Review Plan`, `Restore`, `Open System Settings`
- Avoid vague actions such as `Continue`, `Process`, `Confirm`, `Do It`
- Secondary actions must still communicate outcome, not just mechanism

## Surface Checklist

### Navigation

#### `Overview`

Primary promise:
- Users understand current system state, estimated space opportunity, and the next safe step.

Copy checks:
- Route subtitle must mention `health`, `estimated space`, and `next safe step`
- Main metric must say `Estimated Space` / `预计释放空间`, not a vague size label
- If a number can change after execution, the detail copy must say so explicitly

Reject if:
- It says `reclaimable` without clarifying it comes from the current plan
- It implies cleanup has already happened when it is only estimated

#### `Smart Clean`

Primary promise:
- Users scan first, review the cleanup plan second, and run it only when ready.

Copy checks:
- Screen subtitle must express the order: `scan → plan → run`
- The primary object on the page must be called `Cleanup Plan` / `清理计划`
- The primary execution CTA must say `Run Plan` / `执行计划`
- The plan-size metric must say `Estimated Space` / `预计释放空间`
- Empty states must say `No cleanup plan yet` / `还没有清理计划`
- Result copy after execution must not imply the remaining plan is the same as the one that just ran

Reject if:
- The UI mixes `preview`, `plan`, and `execution` as if they were the same concept
- The primary CTA implies execution when the user is only rebuilding the plan
- The metric label can be mistaken for already-freed space

#### `Apps`

Primary promise:
- Users inspect app footprint, leftover files, and the uninstall plan before removal.

Copy checks:
- `Preview` should be a review verb, not the main object noun
- The actionable object must be `Uninstall Plan` / `卸载计划`
- `Footprint` and `Leftover Files` must remain distinct concepts
- The destructive CTA must say `Run Uninstall` / `执行卸载`
- Row footnotes should identify leftovers clearly and avoid generic file language

Reject if:
- App size and uninstall result size are described with the same noun without context
- `Preview` is used as the label for something the user is actually about to run
- Leftovers are described as errors or threats

#### `History`

Primary promise:
- Users can understand what happened and what can still be restored.

Copy checks:
- Timeline language must distinguish `ran`, `finished`, and `still in progress`
- Recovery copy must mention the retention window where relevant
- Restore CTA and hints must make reversibility explicit

Reject if:
- It sounds like recovery is permanent
- It hides the time window for restoration

#### `Permissions`

Primary promise:
- Users understand why access matters, whether it can wait, and how to proceed safely.

Copy checks:
- The screen must frame permissions as optional until needed by a concrete workflow
- `Not Needed Yet` / `暂不需要` is preferred over pressure-heavy phrases
- The settings-opening CTA must say `Open System Settings` / `打开系统设置`
- Per-permission support text must explain when the permission matters, not just what it is

Reject if:
- It implies Atlas itself grants access
- It pressures the user with mandatory or fear-based wording
- It mentions system scope without user-facing benefit

#### `Settings`

Primary promise:
- Users adjust preferences and review trust/legal information in one calm surface.

Copy checks:
- Active preferences must read like operational controls, not legal copy
- Legal and trust text must stay descriptive and low-pressure
- Exclusions must clearly say they stay out of scans and plans
- Recovery retention wording must describe what remains recoverable and for how long

Reject if:
- Legal copy dominates action-oriented settings
- Exclusions sound like deletions or irreversible removals

### Supporting Surfaces

#### `Task Center`

Primary promise:
- Users see recent task activity and know when to open History.

Copy checks:
- Empty state must name concrete actions that populate the timeline
- Active state must point to History for the full audit trail
- Use `task activity`, `timeline`, `audit trail`, and `recovery items` consistently

Reject if:
- It uses internal terms such as queue/event payload/job object

#### Toolbar and Commands

Primary promise:
- Users understand what happens immediately when they click a global command.

Copy checks:
- `Permissions` global action should say `check status`, not just `refresh`
- `Task Center` should describe recent activity, not background internals
- Command labels should mirror the current screen vocabulary (`Run Plan`, `Check Permission Status`, `Refresh Current Screen`)

Reject if:
- Global actions use different verbs than in-page actions for the same behavior

## State-by-State Review Checklist

Use this table whenever copy changes on any screen.

| State | Must explain | Must avoid |
|------|--------------|------------|
| Loading | What Atlas is doing right now | vague spinner-only language |
| Empty | Why the page is empty and what action repopulates it | blame, dead ends |
| Ready | What the user can review now | implying work already ran |
| Executing | What is currently being applied | silent destructive behavior |
| Completed | What finished and what changed | overstating certainty or permanence |
| Recoverable | What can still be restored and for how long | implying indefinite restore availability |
| Limited mode | What still works and when more access might help | coercive permission language |

## Fast Acceptance Pass

A copy change is ready to ship when all of the following are true:

- Every primary surface has one clear noun for the object the user is acting on
- Every destructive CTA names the actual action outcome
- Every permission CTA names the real system destination
- Every reclaimable-space metric says whether it is estimated and whether it recalculates
- Recovery language always mentions reversibility or the retention window where relevant
- Chinese and English versions communicate the same product model, not just literal translations

## Recommended Use

Use this walkthrough when:

- editing `Localizable.strings`
- reviewing new screens or empty states
- preparing beta QA scripts
- checking regression after feature or IA changes
- writing release notes that reference Smart Clean, Apps, History, or Permissions
