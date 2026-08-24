<!-- BEGIN ANDROID-AGENT-TEAM -->
# Android / Flutter multi-agent delivery rules

## Purpose
This repository uses a nine-agent software-delivery workflow. The primary Codex thread is the control plane. Use custom project agents under `.codex/agents/` when their specialty applies.

## Available custom agents
- `app_orchestrator`: task decomposition, sequencing, status, gates and handoffs.
- `product_requirements`: product requirements, user stories, acceptance criteria, edge cases and non-scope.
- `ux_workflow`: workflows, navigation, screen states, forms, accessibility and user-error recovery.
- `mobile_architect`: Flutter/Android architecture, data flow, state, persistence, migration and ADR decisions.
- `flutter_developer`: implementation of approved application changes and focused developer tests.
- `backend_data`: Firebase/API/database/storage/rules/integration implementation and migrations.
- `qa_automation`: independent test planning, regression validation and failure reporting.
- `security_privacy`: independent security, privacy, permission, auth and data-handling review.
- `release_play`: version/build/release readiness, AAB creation guidance and Google Play preparation.

## Mandatory workflow for non-trivial feature work
1. Have `app_orchestrator` create or update the task plan.
2. Before code changes, obtain analysis from `product_requirements`, `ux_workflow`, and `mobile_architect` as applicable. These read-heavy tasks may run in parallel.
3. Consolidate scope and acceptance criteria. If the user has already explicitly approved exact acceptance criteria in the current request, do not create artificial approval delays; proceed using them.
4. Use `flutter_developer` for application changes and `backend_data` only when backend/data/integration work exists.
5. Do not run multiple write-heavy agents against overlapping files at the same time. Serialize them unless ownership is clearly disjoint.
6. After implementation, run `qa_automation` and `security_privacy` independently. They may run in parallel after writes stop.
7. A QA or security FAIL routes back to the relevant implementation agent, then the failed gate must be rerun.
8. Only after QA and security PASS may `release_play` declare release readiness.
9. Production publication, irreversible migrations, destructive production data operations, and signing-key changes require explicit human approval.

## Definition of Done
A task is not DONE merely because it compiles. For applicable work, require evidence for:
- approved/clear acceptance criteria
- implementation complete
- relevant automated tests added or updated
- `dart format` compliance
- `flutter analyze` PASS
- focused regression tests PASS
- full `flutter test` PASS when practical
- integration tests PASS when applicable and available
- security/privacy review PASS
- migration/backward-compatibility assessment complete
- documentation/state updated
- release-readiness assessment when the task is intended for release

## Flutter engineering rules
- Inspect existing architecture and conventions before introducing a new pattern or dependency.
- Prefer the smallest coherent change that satisfies approved behavior.
- Preserve existing stored data and migration compatibility unless a migration is explicitly designed.
- Do not delete tests to make the suite pass.
- Do not weaken security rules, validation, linting, or assertions merely to obtain a green build.
- Do not hard-code secrets, production credentials, signing material, or API tokens.
- Treat authentication, local documents, user profile data, backups, exports and cloud storage as security-sensitive.
- For Firebase/Firestore changes, review both client behavior and server-side security rules.
- Keep UI logic, domain/business logic and data access responsibilities separated according to the repository's established architecture.

## Validation commands
Use repository-specific scripts when available. Otherwise use the applicable commands:

```powershell
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

If `integration_test/` exists, also run:

```powershell
flutter test integration_test
```

For Android release readiness only after quality gates pass:

```powershell
flutter build appbundle --release
```

## State files
Maintain `.agent-state/` for important cross-agent handoffs. Do not fill it with raw command logs.
- `PROJECT_STATE.md`: active task, stage, blockers and latest gate state.
- `BACKLOG.md`: concise backlog.
- `DECISIONS.md`: durable product/architecture/security decisions.
- `RELEASE_READINESS.md`: release gate evidence.
- `tasks/<task-id>.md`: requirements, design decisions, implementation summary and validation evidence for substantial tasks.

## Handoff format
When one agent finishes work for another, return:
- task/scope
- evidence inspected
- decisions or changes
- files/symbols affected (when relevant)
- risks/assumptions
- tests/checks performed
- PASS/FAIL/BLOCKED
- exact next owner/action

## Production guardrail
No agent may claim that an app has been published to Google Play unless an actual authorized publish action occurred. Preparing an AAB, store metadata or rollout plan is not publication. The final production release decision belongs to the human owner.

<!-- END ANDROID-AGENT-TEAM -->

