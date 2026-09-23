# Task handoffs

HomeVault uses one durable Markdown state file for each substantial AI-assisted feature or fix.

## Naming

GitHub-triggered work must use:

`GH-<issue-number>-<short-slug>.md`

Example:

`GH-72-warranty-reminders.md`

Non-GitHub historical tasks may retain their existing names.

## Purpose

The task file is the shared handoff contract between:

- app_orchestrator
- product_requirements
- ux_workflow
- mobile_architect
- flutter_developer
- backend_data
- qa_automation
- security_privacy
- code_reviewer
- release_play
- the human owner

Agents must read the task file before acting and update only the sections they own.

Do not silently overwrite decisions made by another specialist.

If two approved decisions conflict, return BLOCKED and route the conflict through app_orchestrator.

## Canonical template

New GitHub AI tasks must begin from:

`TASK_TEMPLATE.md`

## Workflow status values

Use only:

- `NEEDS_ORCHESTRATION`
- `PLANNING`
- `IMPLEMENTING`
- `VALIDATING`
- `REPAIRING`
- `BLOCKED`
- `NEEDS_HUMAN`
- `READY_FOR_HUMAN`
- `COMPLETE`

## Current stage values

Use only:

- `ORCHESTRATION`
- `REQUIREMENTS`
- `UX`
- `ARCHITECTURE`
- `IMPLEMENTATION`
- `QA`
- `SECURITY`
- `CODE_REVIEW`
- `REPAIR`
- `RELEASE_READINESS`
- `HUMAN_REVIEW`
- `COMPLETE`

## Gate status values

QA, Security, Code Review and Release Readiness must use only:

- `NOT_RUN`
- `PASS`
- `FAIL`
- `BLOCKED`
- `NOT_APPLICABLE`

A gate must not report PASS without evidence.

## Repair loop

Automated repair attempts are limited to:

`max_repair_attempts: 3`

Each repair must:

1. Increment `repair_attempt`.
2. Record the failing gate.
3. Record the responsible implementation owner.
4. Record the files changed.
5. Rerun the affected validation.
6. Rerun the gate that originally failed.
7. Append an entry to Repair History.

When the maximum automatic repair count is reached and a blocking failure remains:

- set `workflow_status: NEEDS_HUMAN`
- add the GitHub `needs-human` label
- stop autonomous implementation

Agents must never reset the repair count to avoid this boundary.

## Required workflow

1. `app_orchestrator`
2. `product_requirements` when applicable
3. `ux_workflow` when applicable
4. `mobile_architect` when applicable
5. `flutter_developer` and/or `backend_data`
6. `qa_automation`
7. `security_privacy`
8. `code_reviewer`
9. repair loop when a blocking gate fails
10. `release_play` when release-related
11. human review

QA and Security may run independently after implementation writes stop.

Code Review runs only after applicable QA and Security gates pass.

## Human-only boundaries

Agents must stop and require explicit human approval for:

- Google Play publication
- production rollout
- destructive production data operations
- irreversible production migrations
- signing-key replacement or rotation
- secret disclosure
- bypassing a failing quality or security gate

## Completion

A task is not COMPLETE merely because code was written.

`workflow_status: COMPLETE` requires the applicable gates to have passed and any required human action to have occurred.
