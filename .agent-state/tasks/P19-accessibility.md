# P19 Accessibility

## Status

- Owner: `app_orchestrator`
- Branch: `feat/p19-accessibility`
- Baseline HEAD: `656d2c8` (`feat: p17 developments`)
- Current HEAD: `73dafeb2d6f91d91f8a3fa8a2b6d6ddc642f335e`
- Stage: Phase 2 COMPLETE / QA PASS; Phase 3 active and ready for implementation
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

## Completed Phase 3 specialist findings

The completed requirements, UX, and architecture reviews are preserved as the acceptance areas, bounded Phase 3 scope, non-scope, risks, QA matrix, and implementation constraints in this record. They do not need to be rerun merely because Flutter execution moved to host PowerShell.

1. **`product_requirements` - PASS:** personas, essential journeys, measurable acceptance areas, severity boundary, supported behavior, and explicit non-scope are complete with no unresolved material product choice.
2. **`ux_workflow` - PASS:** route/component expectations cover TalkBack names, roles, states, reading/focus order, form and asynchronous recovery, transient UI, repeated content, and representative smoke behavior.
3. **`mobile_architect` - PASS:** the shared semantics and focused behavioral-test approach is approved; Phase 2 form behavior remains the regression baseline; no new dependency, integration harness, platform configuration, backend/data change, storage migration, or ADR is required.
4. **`app_orchestrator` - PASS:** the findings are consolidated into the bounded implementation scope and gate sequence below, with `flutter_developer` as the sole owner of overlapping Phase 3 application/test writes.

## Delivery plan and gates

1. **Baseline — COMPLETE:** branch/HEAD, working-tree file set, purposes, and hashes captured; application source/tests untouched.
2. **Requirements gate — PASS:** the completed product findings cover the eight acceptance areas, severity boundary, supported behavior, and explicit Phase 3 non-scope. These findings remain authoritative for implementation.
3. **UX gate — PASS:** the completed route/component findings define screen-reader names, roles, states, focus/reading order, dynamic announcements, transient UI, repeated-content behavior, recovery, and representative smoke expectations. These findings remain authoritative for implementation.
4. **Architecture gate — PASS:** the completed findings approve the shared-semantics and focused behavioral-test approach, preserve Phase 2 form behavior, and identify no new dependency, backend/data work, platform change, or migration.
5. **Scope consolidation — PASS:** the bounded Phase 3 scope, non-scope, owners, gate sequence, acceptance areas, and QA matrix below are implementation-ready.
6. **Implementation gate — NOT STARTED / READY:** `flutter_developer` completes approved slices serially, preserves unrelated working-tree changes and user data, and adds/updates focused tests. `backend_data` is not planned and is engaged only if a genuine approved dependency emerges.
7. **Automated QA gate — PENDING FOR PHASE 3:** after implementation, run Dart format validation, `flutter analyze`, focused Phase 2/Phase 3 accessibility tests, affected regressions, applicable guards, and full `flutter test`. A failure routes back to `flutter_developer`, then the failed checks are rerun.
8. **Security/privacy gate — PENDING FOR PHASE 3:** after implementation writes stop, `security_privacy` independently verifies that semantics/live regions expose no PINs, credentials, private profile data, document contents/paths, raw exceptions, or other protected values and that auth/destructive boundaries remain intact.
9. **Android TalkBack/device-smoke gate — DEFERRED TO PHASE 4:** physical-device/emulator TalkBack certification, comprehensive contrast, and comprehensive large-text validation are outside the bounded Phase 3 implementation scope.
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

- Existing Phase 1/Phase 2 changes predate or sit outside the Phase 3 implementation pass; retain them as regression baselines unless a verified Phase 3 defect requires a bounded change.
- `ExcludeSemantics` plus explicit semantic actions can create duplicated or misleading activation behavior if not tested with TalkBack.
- Global 48 dp theme minimums can cause overflow or density regressions in compact forms and dialogs.
- Source-string contract tests are brittle and cannot substitute for semantics-tree, widget, regression, or device evidence.
- App-wide scope can expand without discipline; the completed severity boundary and explicit non-scope must govern implementation and deferrals.
- Architecture confirms no data/schema migration, backend work, new dependency, or platform change is required. Phase 3 security/privacy review remains mandatory after implementation.

## Exact next specialist actions

1. Assign `flutter_developer` the preserved bounded Phase 3 scope, acceptance areas, UX/architecture constraints, QA matrix, and explicit non-scope in this record.
2. Implement the smallest coherent screen-reader remediation and focused semantic coverage with serialized writes; preserve unrelated working-tree changes and do not infer implementation completion from the current commit title.
3. After writes stop, assign `qa_automation` and `security_privacy` independently; any genuine failure returns to `flutter_developer` and the failed gate is rerun.
4. Only after Phase 3 QA and security/privacy PASS may `release_play` assess release impact. Phase 4 device certification and human-controlled publication remain separate.

## Phase 3 control-plane record - updated 2026-08-25

### Resolved Phase 2 baseline history

- Commit `73dafeb` is titled `feat: P19 phase 3`, but its changed files implement the Phase 2 accessible-form wrapper, six form integrations, and Phase 2 tests. The title is not evidence that the requested Phase 3 audit is complete.
- The initial 2026-08-24 focused regressions exposed traversal-query scoping, semantics-tree live-region assertion, and stale required-label test-contract issues. APP-04 corrected those issues without changing application source.
- The managed Windows sandbox could not supply the required Flutter execution evidence. The approved host-validation fallback and subsequent APP-06 independent review cleared that environment block on 2026-08-25.
- Phase 2 is COMPLETE / QA PASS. The final evidence and verdict are recorded below; no Phase 2 rerun remains queued.

### Bounded Phase 3 scope after Phase 2 PASS

- App-wide semantic names for icon-only/action/navigation/auth/document/appliance/service/backup/settings controls, avoiding duplicate names where visible text already suffices.
- Correct roles, headings, values, enabled/disabled, checked/selected/expanded, progress/loading, dialog/sheet/menu, list/card, image/icon, navigation, and reading-order semantics across the user-listed routes.
- Concise live-region behavior for material asynchronous outcomes and validation, with deduplication and no private/internal values, IDs, paths, filenames, raw exceptions, PINs, or credentials.
- Phase 2 form regression only; no redesign unless a genuine defect is found.
- Focused behavioral semantic tests covering representative labels/actions/headings/states/live regions/images/navigation/dialogs/repeated content and duplicate-node prevention.

### Explicit Phase 3 non-scope

- Complete color/contrast audit, comprehensive large-text audit, physical-device TalkBack walkthrough, and final Android accessibility certification (Phase 4).
- Backend/data/schema/Firebase/security-rule changes unless a genuine dependency is demonstrated and separately approved.
- Unrelated architecture cleanup, visual redesign, product capabilities, production release/build/publication, signing changes, destructive operations, or irreversible migrations.

### Phase 3 sequence and owners

1. `product_requirements`, `ux_workflow`, and `mobile_architect` reviews are COMPLETE / PASS and remain preserved in this record.
2. `app_orchestrator` consolidation is COMPLETE / PASS; the bounded remediation/test matrix is ready for implementation.
3. After Phase 2 PASS only, `flutter_developer` owns all overlapping application/test writes. `backend_data` remains unassigned unless needed.
4. After writes stop, `qa_automation` and `security_privacy` validate independently and may run in parallel. Failures return to `flutter_developer`, then the failed gate is rerun.
5. Only after QA and security PASS may `release_play` assess release impact. It must not build/publish or claim Google Play publication.

### Required Phase 3 gates

- Acceptance criteria/UX/architecture consolidation PASS.
- Implementation and focused semantic coverage complete.
- `git diff --check`, Dart format validation, `flutter analyze`, focused Phase 2 and Phase 3 regressions, relevant accessibility regressions, full `flutter test`, and applicable source/navigation/security guards PASS.
- Independent QA PASS and security/privacy PASS, including proof that semantics/live regions do not expose protected or internal data.
- Backward compatibility assessed; no migration expected.
- Release-impact assessment only after the preceding gates pass.

## Final Phase 2 gate handoff - 2026-08-25

### Corrections completed by APP-04

- Test-only: scope the ordered `FocusTraversalGroup` assertion to the `HomeVaultAccessibleForm` subtree.
- Test-only: enable the semantics tree and assert the keyed validation summary label plus live-region flag behaviorally.
- Test-only: replace the stale `Appliance name *` widget expectation with `Appliance name (required)`.
- Application source, backend/data behavior, Firebase rules, authentication, and storage behavior were not changed.

### Independent APP-06 evidence

- PASS: git diff/check.
- PASS: Dart format validation, 216 files checked.
- PASS: applicable source guards, 17/17.
- PASS: release-security guards, 4/4.
- PASS via approved Windows host-validation fallback: `C:\Projects\HomeVault-Test-Reports\homevault-validation-20260825-001750.log` (SHA-256 `D1017D749D58A14AA5D3D2355F2DD910B2AF56AC313488AF99A74D5631D664FA`).
- PASS: `flutter analyze` and Dart format validation.
- PASS: focused accessibility regressions 14/14 and full Flutter suite 341/341.
- PASS: APP-06 independently verified that the fresh host evidence applies to branch `feat/p19-accessibility` at HEAD `73dafeb2d6f91d91f8a3fa8a2b6d6ddc642f335e` and returned test-integrity PASS and runtime-integrity PASS.
- Environment resolution: the earlier managed-sandbox Flutter execution block is cleared. Host-side execution supplied the missing runtime evidence; it did not replace APP-06's independent review.

### Final gate decision

Phase 2 is COMPLETE / QA PASS. No failed or environment-blocked Phase 2 gate remains. Phase 3 requirements, UX, and architecture findings remain complete and preserved; Phase 3 implementation is active and ready but has not started.

The current HEAD title `feat: P19 phase 3` is not implementation evidence and must not be used to mark Phase 3 complete.

Exact next action: assign `flutter_developer` the preserved Phase 3 scope and acceptance matrix to implement the bounded screen-reader remediation plus focused semantic tests; after writes stop, route the result to independent `qa_automation` and `security_privacy` gates.
