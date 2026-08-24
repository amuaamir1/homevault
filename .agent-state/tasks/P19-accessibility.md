# P19 Accessibility

## Status

- Owner: `app_orchestrator`
- Branch: `feat/p19-accessibility`
- Baseline HEAD: `656d2c8` (`feat: p17 developments`)
- Stage: Baseline captured; specialist discovery pending
- Started: 2026-08-24
- Overall status: IN PROGRESS

## Goal

Make HomeVault's essential Android journeys understandable and operable with TalkBack, large text/display scaling, and accessible touch interaction, while preserving existing behavior, stored data, privacy controls, and security-sensitive confirmations.

## Preserved uncommitted baseline

This inventory records the P19 work present before orchestration. It is evidence only: no application source or test was modified, reverted, formatted, staged, or otherwise normalized during baseline capture. File hashes are SHA-256 hashes of the working-tree bytes observed on 2026-08-24.

| Path | Git state | Observed P19 purpose | SHA-256 |
|---|---|---|---|
| `lib/app.dart` | modified | Loading-state live-region semantics | `f06bfb27930911bcf65acfedf122bb5393dd0d21e843f164c51801385ffc1b34` |
| `lib/screens/dashboard/dashboard_screen.dart` | modified | Dashboard headings, labels, reminder semantics, and responsive large-text metrics | `980560934e9cc9066ab26c60e1180db38d3f4b7430d0ceeaa1868a9c7c612610` |
| `lib/theme/app_theme.dart` | modified | Global padded tap targets and 48 dp button minimums | `cffe3bf33d1861981114263d4f20d6912a28ddb5f48280c22fae2d910186b533` |
| `lib/widgets/dashboard_card.dart` | modified | Combined value/title semantics and non-truncating layout | `e188fa36dc229c0a2ec72fb9dc99e6ece111fe17e30b248777f8de15c78c7f78` |
| `lib/widgets/empty_state.dart` | modified | Empty-state heading semantics | `0c55846a07a12adf3d564707738beef3676afc29aeadb0cb238e834ad9896785` |
| `lib/widgets/quick_action_tile.dart` | modified | Button semantics and large-text-safe layout | `fb924cc74ee7a579c4e4055fe1dd9f81a0e987ab4bed3d063c0c580fb87f26dd` |
| `lib/accessibility/homevault_accessibility.dart` | untracked | Shared touch-target, text-scale, responsive-column, and count-label helpers | `451ddf8c182f88bd9f0b144fa7a6b8ebbefa270c2c36e27f8b4762f0580db10f` |
| `test/homevault_accessibility_test.dart` | untracked | Helper unit coverage | `3281de1432266b6302ad3cd1200450c6cf4705392260be1a21754c4326770650` |
| `test/p19_phase1_accessibility_contract_test.dart` | untracked | Phase 1 source-contract coverage | `105a257f3875c48966af7d71084c6baccdfeb591bb8fc3a8f0114782639ae107` |
| `test/p19_phase1_accessibility_widgets_test.dart` | untracked | Touch-target and large-text widget coverage | `ee648a3a680b07bb57c8b33766209db408ca47c7c38d2cee174aed3b41f15a95` |

Other untracked repository support files (`.codex/`, `AGENTS.md`, `agent.ps1`, `.agent-state/`, and validation/release scripts) were observed but are not classified as P19 implementation baseline. They must not be swept into P19 changes without separate ownership. No `integration_test/` directory exists at baseline.

## Bounded scope

### In scope

- Establish a consistent semantics model for actionable controls, headings, counts/status, images/icons that convey meaning, loading/progress, empty/error states, dialogs, confirmations, and asynchronous feedback.
- Ensure essential tasks remain readable and operable under Android font/display scaling, including narrow layouts, without clipped, overlapped, hidden, or ellipsized essential content.
- Meet at least 48 by 48 logical-pixel targets for interactive controls and preserve clear enabled, disabled, selected, checked, expanded, error, and destructive-action states.
- Preserve predictable TalkBack reading order, focus movement, route/dialog announcements, navigation state, and recovery after validation or asynchronous errors.
- Verify information and status are not communicated by color alone and that text/icon contrast is suitable in supported light/dark states where applicable.
- Add durable automated coverage at helper, widget, semantics, contract, and regression levels; add an integration harness only if the architecture/QA reviews find it necessary and proportionate.
- Perform a recorded Android TalkBack smoke on a supported device or emulator after automated gates pass.

### Non-scope

- Visual redesign, unrelated copy changes, new product capabilities, or navigation restructuring that is not required for an accessibility blocker.
- Backend, Firestore, storage schema, authentication model, or data migration changes unless a specialist demonstrates they are strictly necessary; none are indicated by the baseline.
- Weakening security confirmations, masking, authorization, validation, privacy controls, lint rules, or existing tests to simplify accessibility behavior.
- iOS-specific VoiceOver certification, desktop/web accessibility certification, Google Play publication, signing changes, or production data operations.
- Treating the current Phase 1 baseline or a clean compile as completion.

## App-wide acceptance areas

The requirements and UX reviews must turn these areas into traceable, testable acceptance criteria and identify critical versus follow-up findings.

1. **Startup, authentication, and app lock:** setup-required, welcome/sign-in, verification, profile/PIN setup, PIN login/reset, legacy upgrade, loading, lock, and sensitive-action verification announce purpose, field state, errors, progress, and recovery without exposing secrets.
2. **Primary navigation and dashboard:** bottom navigation communicates selected state; dashboard headings, metrics, quick actions, badges, search, and shortcuts have concise non-duplicated semantics and logical focus order.
3. **Appliances, warranty, service, and reminders:** lists, filters, status chips, dates/countdowns, details, add/edit forms, schedules, provider actions, and reminder states expose names, roles, values, errors, and actionable context.
4. **Documents, reports, export, and backup/restore:** attachment inputs, document lists/details, progress, share/export/save outcomes, backup/restore choices, warnings, and failure recovery remain operable without disclosing protected file content in unintended announcements.
5. **Search, support, and feedback/admin:** search query/results/empty states, call/email/web actions, service requests, feedback forms and admin views provide usable labels, result context, validation, progress, and focus restoration.
6. **Profile, settings, account data, storage, security, and deletion:** switches, selectors, summaries, destructive actions, confirmations, re-authentication, deletion, and data-management status communicate state and consequences while preserving privacy and authorization boundaries.
7. **Shared system states and components:** app bars, cards, tiles, chips, buttons, icon-only controls, dialogs, sheets, snackbars, live regions, loaders, empty/error states, date/time inputs, and notifications avoid duplicate/noisy announcements and meet target-size/contrast expectations.
8. **Adaptive presentation:** essential content and actions remain available at Android large/maximum practical font and display scales, on narrow portrait layouts, and with keyboard obscuration; scrolling is allowed and fixed heights do not cause loss of content.

## Required specialist reviews

All three discovery reviews may run in parallel. They are read-only for application source/tests and may write only concise handoffs under `.agent-state` while the current write authorization remains in force.

1. **`product_requirements`:** define P19 personas, essential journeys, user stories, measurable acceptance criteria, severity/priority rules, supported Android accessibility settings, explicit non-scope, and the boundary between release-blocking P19 work and later backlog. Map every criterion to the eight acceptance areas above and call out ambiguous product choices.
2. **`ux_workflow`:** audit all routes and shared interaction patterns for TalkBack naming/roles/states, reading and focus order, touch targets, large text/reflow, contrast/non-color cues, forms/errors, dialogs, async announcements, and recovery. Return a route/component matrix with severity and expected behavior, including a concrete TalkBack smoke script.
3. **`mobile_architect`:** assess the preserved helper/theme/semantics approach, risks of `ExcludeSemantics` and duplicated `onTap`, responsive layout strategy, test seams, cross-screen reuse, navigation/focus announcements, and backward compatibility. Confirm whether any dependency, integration-test harness, platform configuration, storage migration, or ADR is needed; default to none unless justified.
4. **`app_orchestrator`:** consolidate the three outputs, resolve conflicts, freeze traceable acceptance criteria and slices, and assign non-overlapping implementation ownership before permitting more application writes.

## Delivery plan and gates

1. **Baseline — COMPLETE:** branch/HEAD, working-tree file set, purposes, and hashes captured; application source/tests untouched.
2. **Requirements gate — PENDING:** product criteria cover all eight areas, distinguish release blockers from later enhancements, and have no unresolved material product choice.
3. **UX gate — PENDING:** route/component audit and reproducible TalkBack script are complete; critical focus, semantics, scaling, contrast, and recovery expectations are explicit.
4. **Architecture gate — PENDING:** shared patterns, test strategy, migration/backward-compatibility assessment, dependency impact, and Android/platform impact are approved.
5. **Scope consolidation — PENDING:** orchestrator publishes the approved criteria-to-change/test matrix and implementation slices. Existing Phase 1 changes are then either adopted, revised, or rejected with rationale.
6. **Implementation gate — PENDING:** `flutter_developer` completes approved slices serially, preserves unrelated working-tree changes and user data, and adds/updates focused tests. `backend_data` is not planned and is engaged only if the approved architecture identifies real backend work.
7. **Automated QA gate — PENDING:** `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze`, focused P19 tests, affected regression tests, and full `flutter test` pass. Any repository script used must be inspected first. Integration tests run if an approved harness exists. A failure routes back to `flutter_developer`, then the failed checks are rerun.
8. **Security/privacy gate — PENDING:** `security_privacy` independently verifies that semantic labels/live regions, notifications, error text, screenshots/recent-app behavior where relevant, export/backup/document flows, and logs do not disclose PINs, credentials, private profile data, document contents/paths, or other sensitive values; auth and destructive confirmation boundaries remain intact. A failure routes back to the responsible implementer and is rerun.
9. **Android TalkBack/device-smoke gate — PENDING:** after automated fixes stop, `qa_automation` runs the approved script on a supported Android device or emulator with TalkBack enabled and large font/display settings. Record OS/API level, device/emulator, build mode, settings, routes covered, focus/announcement results, layout failures, and evidence. Critical/major failures block completion and return to implementation.
10. **Completion/release-readiness gate — PENDING:** orchestrator confirms every approved criterion has evidence, all automated/QA/security/device gates pass, migration/backward compatibility is resolved, durable state is current, and no P19 blocker remains. If P19 is a release candidate, `release_play` then assesses version/build/AAB/store impact; it must not claim or perform publication without human approval.

## QA minimum matrix

- Semantics tests for labels, roles, enabled/selected/checked states, headings, values, live regions, and elimination of duplicate actionable nodes.
- Widget tests at normal and at least 2.0 text scale with constrained/narrow widths, including forms, lists/cards, dialogs, empty/error/loading states, and persistent primary actions.
- Target-size checks for icon-only and custom tappable controls; regression checks for keyboard reachability/focus where Flutter supports it.
- Golden or contrast evidence only where stable and useful; do not replace semantic/widget assertions with screenshots alone.
- Regression coverage for navigation, auth/lock, save/edit/delete, search/filter, document/export/backup, support actions, reminders, and error recovery in proportion to touched code.
- Full suite and Android TalkBack/device smoke as separate required evidence; passing widget tests does not waive the device gate.

## Completion criteria

P19 is DONE only when requirements, UX, and architecture outputs are consolidated; implementation matches the approved bounded scope; every release-blocking acceptance criterion maps to passing automated or recorded manual evidence; formatting, analysis, focused regressions, and the full practical test suite pass; security/privacy and Android TalkBack/device-smoke gates independently pass; migration/backward compatibility and documentation/state are complete; and no critical or major accessibility defect remains open. Deferred non-blocking findings must have explicit backlog entries, severity, rationale, and owner. A build or Phase 1 dashboard improvement alone is insufficient.

## Risks and assumptions

- The existing changes predate the required specialist reviews; they may be retained only after review and consolidation.
- `ExcludeSemantics` plus explicit semantic actions can create duplicated or misleading activation behavior if not tested with TalkBack.
- Global 48 dp theme minimums can cause overflow or density regressions in compact forms and dialogs.
- Source-string contract tests are brittle and cannot substitute for semantics-tree, widget, regression, or device evidence.
- App-wide scope can expand without severity rules; the requirements review must define release blockers and deferrable findings.
- The baseline indicates no data/schema migration and no backend work, but architecture and security reviewers must confirm.

## Exact next specialist actions

1. Run `product_requirements`, `ux_workflow`, and `mobile_architect` in parallel with the read-only briefs under **Required specialist reviews**. Each must inspect the preserved working tree, avoid application/test writes, and save or return a concise PASS/FAIL/BLOCKED handoff with evidence, risks, and exact next action.
2. Return all three handoffs to `app_orchestrator`; do not start or resume `flutter_developer` writes first.
3. Have `app_orchestrator` consolidate the reviews into approved acceptance criteria, a route/component coverage matrix, and serialized implementation slices, then update this task and `PROJECT_STATE.md`.
4. Only after consolidation, assign `flutter_developer` to reconcile the preserved baseline and implement the approved slices. After writes stop, assign `qa_automation` and `security_privacy` in parallel; QA also owns the final Android TalkBack/device smoke.
