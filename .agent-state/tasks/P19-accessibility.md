# P19 Accessibility

## Status

- Owner: `app_orchestrator`
- Branch: `feat/p19-accessibility`
- Baseline HEAD: `656d2c8` (`feat: p17 developments`)
- Current HEAD: `fcba96b74c9f4596b320add560444f63fee9d918`
- Stage: Phase 1 COMPLETE; Phase 2 COMPLETE / QA PASS; Phase 3 COMPLETE / QA PASS / SECURITY PASS / RELEASE-IMPACT PASS; Phase 4 ACTIVE / PLANNING COMPLETE
- Started: 2026-08-24
- Overall status: OPEN

### Phase status

- P19 Phase 1: COMPLETE
- P19 Phase 2: COMPLETE / QA PASS
- P19 Phase 3: COMPLETE / QA PASS / SECURITY PASS / RELEASE-IMPACT PASS
- P19 Phase 4: ACTIVE / PLANNING COMPLETE
- P19 overall: OPEN

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
6. **Implementation gate — PASS:** `flutter_developer` completed the approved slices serially, preserved unrelated working-tree changes and user data, and added focused behavioral semantics tests. `backend_data` was not needed.
7. **Automated QA gate — PASS FOR PHASE 3:** host validation passed Dart format, `flutter analyze`, focused Phase 3 tests 10/10, `widget_test.dart` 10/10, and the full Flutter suite 352/352; APP-06 independently returned QA PASS.
8. **Security/privacy gate — PASS FOR PHASE 3:** APP-07 found no confirmed security or privacy finding and no weakening of rules, configuration, authentication, or account isolation.
9. **Android TalkBack/device-smoke gate — PENDING FOR PHASE 4:** the comprehensive contrast audit, comprehensive large-text audit, physical TalkBack walkthrough, and final Android accessibility/device certification remain open and outside the completed Phase 3 scope.
10. **Phase 3 release-impact gate — PASS:** APP-08 returned PASS FOR P19 PHASE 3 CLOSEOUT with LOW functional risk and no migration/data, Firebase/security/config, or Android/build impact. P19 overall remains OPEN pending Phase 4; no production or publication action is authorized.

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

1. `app_orchestrator` opens the bounded P19 Phase 4 plan.
2. Phase 4 retains the comprehensive color/contrast audit, comprehensive large-text audit, physical TalkBack walkthrough, and final Android accessibility/device certification.
3. Do not mark P19 complete until Phase 4 evidence and its applicable independent gates pass.
4. Keep commit, push, merge, tag, production build/signing/publication, migrations, and version changes under explicit human control.

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
2. `app_orchestrator` consolidation is COMPLETE / PASS; the bounded remediation/test matrix was implemented without expanding scope.
3. `flutter_developer` application/test writes are COMPLETE / PASS. `backend_data` remained unassigned because no backend dependency was found.
4. `qa_automation` and `security_privacy` completed independent Phase 3 review: APP-06 QA PASS and APP-07 security/privacy PASS.
5. `release_play` completed the Phase 3 release-impact assessment: APP-08 PASS. It did not build, publish, or claim Google Play publication.

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

At the time of this Phase 2 gate handoff, Phase 3 implementation had not started. The current Phase 3 status is recorded in the implementation handoff below.

The current HEAD title `feat: P19 phase 3` is not implementation evidence and must not be used to mark Phase 3 complete.

The previously recorded `flutter_developer` assignment is complete; the current next action is recorded in the Phase 3 implementation handoff below.

## Phase 3 implementation handoff - 2026-08-25

### Implementation completed

- Added shared contextual-action, live-region, and genuine-section-heading semantics helpers without introducing a dependency or architecture change.
- Added state-aware password visibility labels and meaningful authentication progress announcements without exposing passwords or PINs.
- Contextualized repeated appliance, document, service-request, service-record, support, export, cloud-backup, and feedback actions, including transient popup-menu items.
- Exposed selected state for custom document filter/sort sheet rows, while excluding decorative check/icons and preserving the existing control behavior.
- Added concise live-region behavior for global-search result counts and authentication, backup/restore, cloud-history, account-deletion, attachment-selection, and device-storage progress. Existing snackbar outcome behavior remains unchanged.
- Added genuine section-heading semantics to cloud-backup, document-detail, and feedback-detail sections; existing AppBar/dashboard/empty-state heading behavior remains intact.
- Added safe descriptions for informative appliance/feedback images and excluded repeated decorative list/dashboard photos.
- Prevented filenames, local/storage paths, feedback UIDs, and technical app/device metadata from entering the screen-reader tree while preserving the visible/admin UI and application data.
- Preserved `HomeVaultAccessibleForm`, required-field semantics, validation-summary live region, ordered form traversal, validation/helper/error behavior, and all authentication/data/security/storage behavior.

### Focused coverage added or updated

- Added `test/p19_phase3_screen_reader_accessibility_test.dart` with behavioral semantics assertions for contextual repeated actions, transient menus, headings, selected filters, live search results, safe image descriptions, hidden filename/internal-ID values, and duplicate actionable-node prevention.
- Updated `test/widget_test.dart` with behavioral selected/unselected navigation-destination coverage.
- Existing Phase 1/Phase 2 accessibility tests remain unchanged and are required in host validation.

### Implementation-time validation evidence

- PASS: `dart --suppress-analytics format --output=none --set-exit-if-changed lib test` (217 files, zero changes).
- PASS: `git diff --check`.
- PASS: read-only icon-action audit found no `IconButton` or `PopupMenuButton` without a tooltip.
- BLOCKED in managed Windows sandbox: `flutter analyze` failed when Flutter could not access Git; direct `dart analyze` failed when the analysis-server subprocess was denied. Per the Windows Flutter policy, these commands were not repeatedly retried.
- The required host validation subsequently ran and passed; the final authoritative evidence is recorded in the Phase 3 closeout below.
- Phase 4 contrast/large-text audit, physical TalkBack walkthrough, and Android accessibility/device certification remain intentionally deferred.

### Status and next action

Implementation owner status: PASS. The subsequent host, QA, security/privacy, and release-impact gates also passed as recorded in the Phase 3 closeout below.

## P19 Phase 3 final closeout - 2026-08-25

### Authoritative evidence

- Host validation report: `C:\Projects\HomeVault-Test-Reports\homevault-validation-20260825-210138.log`
- Report SHA-256: `CBE95770DFA66CED74502E33D9F5CDC9AA0495A6174CD57D47A7B25D2C2BCC15`
- Git HEAD: `fcba96b74c9f4596b320add560444f63fee9d918`
- Host validation: Flutter environment PASS; package resolution PASS; Dart format PASS; `flutter analyze` PASS; Phase 1 PASS; Phase 2 PASS; Phase 3 focused screen-reader suite 10/10 PASS; `widget_test.dart` 10/10 PASS; full Flutter suite 352/352 PASS; OVERALL PASS.
- Repository check: `git diff --check` PASS.
- APP-06: QA PASS.
- APP-07: security/privacy PASS; no confirmed security or privacy findings and no rules, config, auth, or account-isolation weakening.
- APP-08: release-impact PASS for P19 Phase 3 closeout; functional risk LOW; no migration/data, Firebase/security/config, or Android/build impact; no additional automated Phase 3 validation required.

### Major Phase 3 outcomes

- Contextual screen-reader action labels and repeated-row action disambiguation.
- Service-record action differentiation, same-day feedback action differentiation, and duplicate-document-title differentiation.
- Selected and navigation semantics plus genuine heading boundaries.
- Live-region and status announcements.
- Safe image semantics and filename/path/internal-ID privacy protections.
- Dialog, menu, and transient-action semantics.
- Duplicate and ambiguous semantic-node prevention.

### Final status and boundary

- P19 Phase 3: COMPLETE / QA PASS / SECURITY PASS / RELEASE-IMPACT PASS.
- P19 Phase 4: PENDING - comprehensive color/contrast audit, comprehensive large-text audit, physical TalkBack walkthrough, and final Android accessibility/device certification.
- P19 overall: OPEN.
- No Phase 4 implementation, production build, signing, publication, migration, version change, commit, push, merge, or tag was performed by this closeout.
- Exact next action: `app_orchestrator` opens the bounded Phase 4 delivery plan and assigns its contrast, large-text, physical TalkBack, and final Android accessibility/device certification gates without reopening the completed Phase 3 gates unless the repository materially changes.

## P19 Phase 4 bounded delivery plan - 2026-08-25

### Objective and phase boundary

Phase 4 will audit and certify HomeVault's supported Android light-theme experience for color/contrast, large text, and physical TalkBack operation across representative critical journeys. It will produce traceable automated, manual, device, QA, security, and release evidence sufficient to decide whether P19 can close. This planning pass does not implement remediation and does not itself certify the app.

Phase 3 remains COMPLETE / QA PASS / SECURITY PASS / RELEASE-IMPACT PASS against `C:\Projects\HomeVault-Test-Reports\homevault-validation-20260825-210138.log` (SHA-256 `CBE95770DFA66CED74502E33D9F5CDC9AA0495A6174CD57D47A7B25D2C2BCC15`). Do not reopen those completed gates unless application/test state materially changes after that evidence.

Phase 4 contains exactly four workstreams:

1. Comprehensive supported light-theme color/contrast audit.
2. Comprehensive representative large-text audit.
3. Human-executed physical Android TalkBack walkthrough.
4. Final Android accessibility/device certification and independent gates.

Non-scope: unrelated redesign; branding, core workflow, backend schema, Firebase architecture/rules/config, authentication design, storage architecture, business-rule, dependency, dark-mode, publication, signing, versioning, migration, commit, push, merge, or tag work. A genuine release-blocking accessibility defect may justify only a bounded, explicitly approved change. HomeVault currently configures `AppTheme.lightTheme` only; dark theme is not a Phase 4 requirement.

### Route and screen audit inventory

Each row must be represented in the contrast and large-text worksheet. The TalkBack device pass uses the critical subset described later while still checking shared components encountered along those journeys.

| Area | Routes/screens and representative states |
|---|---|
| Startup and authentication | Firebase setup-required, account check/loading, welcome/sign-in, password visibility, password recovery, email verification, legacy email upgrade, profile setup, PIN setup, PIN login/app lock, reset PIN with password, sensitive-action verification, loading/error/retry states |
| Primary navigation and home | Home/dashboard, bottom navigation Home/Service center/Support/Settings, metrics, quick actions, reminder summaries, badges, cards, loading/empty/error/status states |
| Appliances | Appliances browse, search, filter and sort menus/sheets, add appliance form, edit flow, appliance details, images, status chips, destructive dialogs |
| Warranty and AMC | Warranty/AMC center, filter/sort, status and countdown states, details reached through appliance flows, reminders and actions |
| Documents | Documents browse, search/filter/sort sheets, add document/attachment field, duplicate-title rows, document details, open/share/delete actions, attachment handling, Save a copy/export outcomes |
| Service center and requests | Service center/history, repeated service records for the same appliance, add/edit records, service requests list, add request, request details, provider prefill, status sheet, delete/confirmation/error states |
| Provider and support directory | Support landing, directory browse/search/filter, provider details, call/email/web actions, request-service actions and unavailable-action states |
| Reminders | Reminder center, filters/status, appliance navigation, empty/error/permission-related states |
| Global search | Query field, loading/live result count, grouped results, duplicate/repeated results, empty and error states, result navigation |
| Reports and exports | Reports/portfolio metrics, tables/list rows, document export, support pack, progress/success/error/share/Save a copy states |
| Feedback | User feedback form, validation and submission states; authorized admin feedback dashboard, filters/sort/status menus, repeated same-day entries, feedback details and images |
| Backup and storage | Backup/restore, cloud backup/history, appliance-selection sheet, restore-mode and destructive confirmation dialogs, progress/success/error states, device storage management |
| Profile, settings and account | Profile, Settings, Security settings, Account data, selectors/switches, cloud/device storage entries, sign-out, account deletion, re-authentication and final destructive confirmation |
| Shared/transient components | App bars, headings, cards, list/document/service/feedback rows, forms, labels/helper/error text, buttons, icon-only actions, controls, selected/disabled/focused states, dialogs, bottom sheets, popup menus, snackbars, live/status/error/warning/success states, empty/loading states, images/background overlays |

### Workstream 1 - color and contrast audit

#### Method and evidence

- Establish a worksheet keyed by inventory row, screen/state, element, foreground/background or adjacent colors, theme/state, measured ratio, required ratio, method/tool, evidence reference, severity, owner, and PASS/FAIL/BLOCKED.
- Inspect the configured light `ColorScheme`, custom `AppColors`, component themes, alpha blending, and direct colors. Automated source inventory is discovery evidence only; it cannot certify rendered contrast.
- Calculate deterministic ratios for stable theme/component color pairs and add focused automated assertions where this is maintainable. Rendered alpha, elevation/tints, images/gradients, disabled opacity, transient states, and device-specific composition require visual sampling/manual confirmation.
- Manually exercise default, pressed where observable, focused where applicable, selected, unselected, enabled, disabled, validation error, warning, success, loading, snackbar, dialog, sheet, and menu states on representative screens.
- For text over images, gradients, or variable backgrounds, measure the least-contrasting area directly behind the text/icon. Require a solid scrim/container/halo or another bounded remedy if any used region fails.
- Record color-independent cues for error/warning/success, selected state, charts/metrics, warranty/service status, and destructive actions; color alone cannot carry meaning.

#### Acceptance criteria

- Normal text and images of normal text meet at least 4.5:1 against the rendered background.
- Large-scale text meets at least 3:1. Classification is based on rendered font size/weight, not on the Android text-scale setting alone; text enlarged by the user does not retroactively waive a failing default style.
- Essential icons, control boundaries needed to identify a control, focus indicators, and visual state indicators meet at least 3:1 against adjacent colors.
- Selected/unselected controls remain distinguishable by more than hue alone and their text/icons meet the applicable ratios. Focus state is visible and distinguishable from unfocused state.
- Enabled errors, warnings, successes, links/actions, status chips, progress indicators, and validation affordances meet the applicable text/non-text ratio and include a non-color cue such as text, icon, shape, state, or semantics.
- Disabled controls are inventoried and manually reviewed. WCAG does not impose the active-control contrast threshold on genuinely inactive controls, but HomeVault acceptance requires them to remain perceivable as intentionally disabled, distinguishable from enabled state, and not mistaken for missing content; any adjacent explanatory text must still meet its applicable text ratio.
- Text/icons over images or variable backgrounds meet the ratio at the least favorable rendered point. Decorative imagery is not treated as an information-bearing control.
- Dialogs, bottom sheets, popup menus, snackbars, loading/error/empty states, destructive confirmations, and keyboard/focus states pass the same criteria as persistent screens.
- Audit coverage is complete for every inventory row and all release-blocking findings are closed or explicitly BLOCKED with device/environment evidence. No critical or major contrast defect remains open.

Reference baseline: WCAG 2.2 AA contrast minimum and resize/non-text criteria, including 4.5:1 normal text, 3:1 large text, and 3:1 essential non-text indicators. Primary references: `https://www.w3.org/TR/WCAG22/`, `https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast`, and `https://www.w3.org/WAI/WCAG22/Techniques/general/G18`.

#### Automation opportunities and manual-only checks

- AUTOMATED: contrast utility tests for stable ARGB pairs; theme-token matrix checks; targeted widget tests for state-specific foreground/background selection; guards that status is not represented only by a color token; stable goldens only as supporting regression evidence.
- MANUAL: rendered pixel sampling after alpha/elevation/image composition; visual discoverability of disabled/selected/focus states; text over images; warning/success/error interpretation; color-deficiency simulation where available; transient UI and system-rendered state. Screenshots support the worksheet but never replace measurements or human review.
- Likely remediation owner: `flutter_developer` after `ux_workflow` documents and APP-00 approves a bounded defect. Theme-wide or platform behavior concerns first route to `mobile_architect`. Independent acceptance owner: `qa_automation`.

### Workstream 2 - representative large-text audit

#### Scale matrix

The deterministic Flutter matrix derives from current Phase 1 conventions rather than arbitrary values:

| Scale | Purpose and source |
|---|---|
| 1.0 | Baseline/default control |
| 1.3 | Moderately enlarged; current `HomeVaultAccessibility.largeTextThreshold` where adaptive column behavior begins |
| 1.7 | Very large; current `HomeVaultAccessibility.veryLargeTextThreshold` where adaptive layouts collapse to one column |
| 2.0 | Strong accessibility/200% regression scale already used by Phase 1 widget tests and aligned with the 200% loss-of-content/functionality boundary |

Automated/widget checks may use `TextScaler.linear` for repeatability. Device certification must additionally use the Android system's actual default and largest practical supported font settings, preserving platform non-linear scaling, and record the displayed setting. Test 1.3 and 2.0 at a representative narrow portrait viewport; add landscape or larger display checks only where a discovered issue or control type warrants them. Display-size interaction is sampled on device rather than replacing font-scale coverage.

#### Audit checks and acceptance criteria

- No RenderFlex/viewport exceptions, clipped glyphs, overlapping controls, obscured labels, inaccessible actions, or lost content at any required scale.
- Essential names, values, dates, status, error/helper text, destructive consequences, and action labels are never hidden solely by ellipsis. Non-critical secondary text may truncate only when the full value is available through an adjacent/detail action and workflow completion is unaffected.
- No unintended horizontal scrolling. Deliberate horizontal scrolling for a genuinely tabular/data surface is permitted only when announced/discoverable, controllable, and no primary action or row identity is stranded off-screen.
- Vertical scrolling and keyboard insets keep the focused field, validation summary, helper/error text, and submit/cancel/destructive actions reachable.
- Cards, metrics, dashboard grids, list/document/service/feedback rows, tables, navigation labels, chips, buttons, popup menus, empty states, and loading/error states reflow without semantic or visual loss. Phase 1 responsive column behavior is preserved.
- Dialogs and bottom sheets scroll or resize so titles, content, choices, errors, and all actions remain reachable; popup menu items remain readable and selectable without clipping.
- Add/edit/auth/feedback/service/backup forms remain usable from first field through validation, correction, and submission at 2.0 and on the actual largest practical Android font setting.
- Bottom navigation and major secondary navigation remain understandable and actionable; scaling must not remove access to a destination.
- All inventory rows have 1.0 and 2.0 evidence; high-density/adaptive screens additionally have 1.3 and 1.7 evidence. No critical or major large-text defect remains open.

#### Automation opportunities and manual/device checks

- AUTOMATED: parameterized widget harnesses at 1.0/1.3/1.7/2.0; narrow viewport plus `tester.takeException()`/overflow detection; visibility and tappability of required actions; scroll-to controls; no essential ellipsis contract where inspectable; dialogs/sheets/forms/navigation/list-row regression tests; preserve existing Phase 1 helper and 2.0 widget tests.
- MANUAL/DEVICE: actual Android non-linear font scaling and largest practical setting; display-size interaction; keyboard obscuration; text legibility/truncation judgment; long realistic values, duplicate titles, localization-like long data, transient UI, data tables, images, and manufacturer/provider/document/service/feedback rows.
- Likely remediation owner: `flutter_developer`, serialized after worksheet triage. `ux_workflow` decides acceptable reflow/content priority; `mobile_architect` is consulted only for a cross-cutting layout/platform concern.

### Workstream 3 - physical TalkBack walkthrough

This is a real Android device/emulator manual gate requiring a human host with TalkBack enabled. Codex and automated semantics tests cannot certify it.

#### Session record

For each run record tester, timestamp/time zone, Git branch and HEAD, working-tree/build identity, build type and artifact/application version if applicable, device/emulator manufacturer/model or AVD, architecture, Android/API version, screen resolution/density/orientation, font and display settings, TalkBack/Android Accessibility Suite version, Flutter/Dart version, connectivity/account role, seeded-data profile, and whether a hardware keyboard or external accessibility input was used. Never put passwords, PINs, tokens, document contents, local paths, or other private data in evidence.

Each checklist row records: journey/step, expected announcement or behavior, actual result, PASS/FAIL/BLOCKED, severity, defect ID, notes, and optional screenshot/screen recording reference. Screenshots are useful for visual/layout issues; spoken output and focus behavior require written notes or a privacy-safe recording. BLOCKED must name the exact environmental/data/authorization precondition and is not a PASS.

#### Common checks applied at every step

- Reading order follows visual/task order and does not strand or skip meaningful content.
- Every actionable item has a concise accessible name, correct role, current state/value, and a useful hint only where the action or consequence is not otherwise clear.
- Swipe and explore-by-touch focus movement is predictable; route transitions, validation, menus, dialogs, sheets, async results, and back navigation place/restore focus sensibly.
- There are no duplicate announcements/actionable nodes, accidental hidden content, unlabeled controls, noisy decoration, raw technical strings, or stale state/value announcements.
- Live announcements are concise, occur once when materially needed, do not interrupt secrets, and cover loading completion, result-count/status changes, validation, success, and failure where appropriate.
- Dialogs, sheets, and popup menus announce themselves/context, trap focus to active content, expose all actions, dismiss/back correctly, and restore focus to the invoker where practical.
- Destructive actions state object and consequence, require intentional confirmation/re-authentication where designed, support safe cancellation/back, and do not weaken the existing workflow.
- Private values are not spoken unexpectedly: PIN/password/credentials, internal IDs, local/storage paths, hidden filenames or document content, private profile/account data, tokens, or raw exceptions.
- The tester can complete the workflow without sight; a visual-only workaround is a FAIL.

#### Critical journey checklist

A. Authentication: launch/setup-required state if available; sign in; traverse email/password controls; toggle password visibility and hear the new state; submit and recover from errors; perform password recovery/email verification/legacy upgrade where available; set up/unlock/reset PIN and complete sensitive-action verification without secret disclosure.

B. Navigation: traverse and activate Home, Service Center, Support, and Settings; verify selected state; reach major secondary destinations including appliances, warranty, documents, reminders, search, reports, backup/storage/profile/security/account; use system/app back and confirm focus restoration.

C. Appliances: browse repeated rows; search, filter, and sort; add and validate/edit an appliance; open details and images/actions; distinguish repeated/contextual controls; cancel and confirm destructive actions safely.

D. Warranty/AMC: browse/filter/sort warranty and AMC states; hear appliance identity, status, dates/countdowns, reminders and actions; open the related appliance/detail journey without relying on color.

E. Documents: browse and filter; distinguish duplicate titles; add/select attachment; open details; execute appropriate open/share/export/Save a copy actions; exercise menus/sheets; verify attachment/file privacy, progress, errors, and delete confirmation.

F. Service: distinguish repeated records for the same appliance; add/edit a service record; browse/create a service request; use provider prefill; update status in a sheet; open request details; recover from validation/error and safely confirm deletion.

G. Search: enter/clear a query, hear result count changes once, traverse grouped/repeated results and empty/error states, activate a result, and return with usable focus.

H. Feedback: submit user feedback through validation/loading/outcome states; with an authorized role only, use the admin dashboard, filter/sort/status actions, distinguish repeated same-day entries, open details/images, and verify private/admin-only values are not exposed unnecessarily.

I. Backup/restore/cloud: browse local backup/restore, support pack, cloud history, device storage and appliance-selection controls; exercise progress/success/failure; open restore-mode and overwrite/destructive confirmations; cancel safely; use a non-production test account/data set.

J. Account and deletion: traverse profile/settings/security/account data; verify switch/selector state; sign out and return safely; start account deletion, hear consequence and re-authentication requirements, cancel once, and only perform final deletion against an explicitly disposable test account authorized by the human host.

Walkthrough acceptance: every common check and critical journey is PASS, or an inapplicable step is marked N/A with rationale. No critical/major TalkBack defect or unexplained BLOCKED row remains. Destructive test steps use disposable test data and human authorization.

### Workstream 4 - final Android accessibility/device certification

P19 can be marked COMPLETE only when one coherent current-tree evidence packet contains:

- Completed contrast worksheet and artifacts with every inventory row covered, ratios/methods recorded, and color/contrast gate PASS.
- Completed 1.0/1.3/1.7/2.0 large-text worksheet plus actual Android default/largest-practical font evidence, with large-text gate PASS.
- Signed/attributed human-host TalkBack checklist with all critical journeys and common checks resolved; TalkBack gate PASS.
- Current-implementation automated regression report: Dart format, `flutter analyze`, focused Phase 1-4 accessibility tests, affected regression tests, `widget_test.dart`, full `flutter test`, and `integration_test` only if it exists/becomes applicable. Windows host fallback may be used under the established APP-06 policy.
- `git diff --check` PASS and an inventory tying evidence to the exact branch, HEAD, working-tree/source hash or clean candidate build, and timestamp. Evidence from an earlier tree is invalid after material remediation.
- Device/build identity, Android version/API, physical model or AVD identity, display/font settings, TalkBack version, app version/build type/artifact identity, and Flutter/Dart version recorded.
- Independent APP-06 QA PASS after it inspects the current changes, worksheets/device evidence, test integrity, host report, defect closure, and regression safety.
- APP-07 security/privacy PASS when Phase 4 source changes touch auth/PIN, documents/attachments, backup/restore/cloud, profile/account/deletion, admin data, semantics/live regions, permissions, storage, or destructive flows. If no Phase 4 source changes occur, APP-00 and APP-06 record APP-07 as not required for re-execution and retain Phase 3 PASS.
- APP-08 release-impact PASS after QA and applicable security gates, covering device/build compatibility, Android/Play accessibility impact, version/build implications, and remaining human-controlled release actions. An AAB is required only if the human owner declares this a release candidate; publication is never implied.
- Migration/backward-compatibility assessment. Default expectation is no schema/backend/storage migration; any deviation requires a separately approved plan.
- No unresolved critical/major Phase 4 defect. Lower-severity deferrals require rationale, owner, backlog entry, user impact, and acceptance by APP-00/APP-06; a release-blocking device limitation cannot be waived silently.

Planning status is not certification. The first device run establishes findings; a rerun after material source remediation must cover the failed journey plus regression-critical journeys and produce fresh build/tree identity.

### Serialized ownership and dependencies

1. `app_orchestrator` - COMPLETE for plan opening: preserve Phase 3 gates, own scope, evidence traceability, severity/triage, and gate sequencing.
2. `ux_workflow` - next owner, read-only: convert the inventory into a route/state worksheet, perform the first-pass contrast and large-text UX audit, classify manual/device needs, and return PASS/findings without application/test writes.
3. `app_orchestrator` - consolidate findings and approve only bounded remediation. Engage `mobile_architect` only if a cross-cutting theme/layout/platform/Android concern arises; engage `security_privacy` before remediation design when sensitive announcements/data/actions are implicated.
4. `flutter_developer` - conditional, sole serialized owner of all overlapping application/test remediation writes; preserve Phase 1 adaptive layout and Phase 3 semantics/privacy behavior. `backend_data` remains unassigned unless an unexpected accessibility blocker truly requires backend/data work and receives separate approval.
5. `qa_automation` - after writes stop (or immediately after audit if no changes): add/approve proportionate automated audit coverage, run current-tree validation, review worksheet completeness, and prepare the device checklist/build identity. Any sandbox-only execution block follows the established host-report fallback.
6. Human host + `qa_automation` - execute and record the physical TalkBack and actual Android font/device walkthrough. Codex may guide and inspect evidence but cannot claim the physical result.
7. `security_privacy` - independently review only when applicable under the sensitive-surface trigger above; may run alongside final QA review only after writes stop.
8. `qa_automation` - issue final APP-06 verdict against all automated/manual/device evidence and the exact current tree. A failed gate returns to remediation and is rerun.
9. `release_play` - only after APP-06 and applicable APP-07 PASS: assess final Android accessibility/device/release impact. It does not publish.
10. `app_orchestrator` - close Phase 4/P19 only after every required gate is green and durable state/evidence is current.

No overlapping write-heavy agents operate concurrently. Human device execution depends on a runnable current candidate, seeded disposable test data/accounts, authorized admin access for admin-only screens, safe backup/deletion fixtures, and recorded device/TalkBack identity.

### Failure-routing model

| Failure type | Route/owner | Required return gate |
|---|---|---|
| Local styling, responsive layout, widget semantics/focus, transient UI, or focused regression defect | `flutter_developer` after APP-00 scope approval | Failed automated/manual/device check, focused regressions, APP-06 QA; security if sensitive |
| Reading order, content priority, reflow choice, hint/announcement UX, journey completion ambiguity | `ux_workflow` for corrected expectation/design, then `flutter_developer` if code is needed | UX acceptance plus affected automated/device checks and APP-06 |
| Cross-cutting theme architecture, Flutter platform behavior, Android accessibility API/build concern | `mobile_architect`, then bounded implementation owner | Architecture decision, affected checks, APP-06, APP-08 |
| Test gap, incomplete worksheet/evidence, inconsistent build identity, reproducibility issue | `qa_automation`; human host repeats device step when needed | APP-06 evidence review |
| Secret/private data announcement, auth/authorization/destructive-flow weakening, unsafe test fixture/evidence | `security_privacy` immediately; then relevant implementation owner | APP-07 and APP-06 rerun |
| Device/emulator/TalkBack environment unavailable or step cannot be safely performed | Human host plus APP-00 records BLOCKED with exact condition; do not call PASS | Repeat on qualifying environment; APP-06 reviews fresh evidence |
| Genuine host Flutter/analyze/test failure | `flutter_developer` or relevant owner, not classified as sandbox block | Fresh host report and APP-06 PASS |
| Windows sandbox-only Flutter execution restriction | `qa_automation` uses established host-validation fallback; do not repeatedly rerun | Fresh timestamped host report for exact tree and APP-06 review |
| Release/build/Android compatibility issue after green QA | `release_play` identifies impact; `mobile_architect`/`flutter_developer` handles approved remedy | APP-06, applicable APP-07, then APP-08 rerun |

### Phase 4 acceptance and QA matrix

| Evidence class | Required acceptance evidence | Gate/owner |
|---|---|---|
| AUTOMATED | Stable theme contrast-pair checks where feasible; parameterized 1.0/1.3/1.7/2.0 narrow-layout tests; overflow/exception/action reachability; affected dialog/sheet/menu/form/list/navigation tests; existing Phase 1-3 accessibility suites; format; analyze; full Flutter suite; diff check | Implementation owner supplies tests; APP-06 independently validates |
| MANUAL | Complete route/state worksheets for rendered contrast, disabled/selected/focus/error/warning/success, text-over-image, color-independent meaning, and visual large-text reflow/truncation/keyboard/transient behavior | `ux_workflow`, then APP-06 review |
| DEVICE | Human-host actual Android default/largest-practical font and display sampling; physical/emulator TalkBack A-J checklist; common name/role/state/value/hint/order/focus/live/transient/back/privacy/destructive checks; recorded device/build/TalkBack identity | Human host executes; APP-06 owns verdict |
| QA | Traceability from every inventory/acceptance row to evidence; current-tree identity; defect severity/closure; no weakened tests; focused and full regression PASS; no unresolved critical/major or unexplained block | APP-06 `qa_automation` PASS required |
| SECURITY | No secrets/private/internal values exposed; authorization and role boundaries intact; account deletion, backup/restore, documents, PIN/auth and destructive confirmations not weakened; privacy-safe evidence. Rerun APP-07 when triggered by sensitive source changes | APP-07 `security_privacy` PASS when applicable; otherwise retain documented Phase 3 PASS |
| RELEASE | Device/build/Android/Flutter identity complete; compatibility/migration impact resolved; APP-06 and applicable APP-07 green; candidate/AAB/Play impact assessed only if applicable; no publication claim or action | APP-08 `release_play` PASS, then APP-00 closeout |

Cross-cutting release acceptance:

- Contrast: complete inventory, required ratios and non-color cues PASS.
- Large text: required deterministic scales plus actual Android setting PASS without loss of content/function.
- TalkBack: A-J journeys completable without sight; names/roles/states/values/hints and privacy correct.
- Focus/reading order: logical, complete, restored after routes/transients, no traps/duplicates/hidden actionable content.
- Live announcements: concise, timely, deduplicated, privacy-safe, and not overly disruptive.
- Navigation: every primary/secondary destination and back path remains identifiable and operable.
- Dialogs/transient UI: context, focus containment, action reachability, dismissal/back, restoration, contrast and reflow PASS.
- Privacy: no secret/internal data disclosure in speech, screenshots, recordings, logs, semantics, status, or errors.
- Destructive actions: clear object/consequence, deliberate confirmation/re-authentication, safe cancel/back, disposable test fixtures.
- Device certification: exact current build/tree and Android/device/TalkBack/Flutter identities recorded with attributed human evidence.
- Regression safety: all required automated checks and independent gates PASS; Phase 1 adaptive layout and Phase 3 semantics/privacy gains remain intact.

### Risks, assumptions, and release implications

- Theme-token calculations can miss alpha blending, images, and system-rendered controls; manual rendered sampling remains mandatory.
- Linear widget scaling is deterministic but not identical to Android's platform non-linear scaling; both automated and device evidence are required.
- Large text can expose fixed heights, dense navigation, keyboard occlusion, and transient-surface issues that are invisible at baseline.
- TalkBack results depend on Android/TalkBack/build identity and seeded data; evidence without these identities is not certifiable.
- Backup, deletion, PIN/auth, documents, and admin journeys are security-sensitive; use disposable accounts/data and do not capture secrets.
- No architecture, backend, schema, Firebase, dependency, storage, migration, Android config, or product-workflow change is currently indicated.
- Phase 4 planning has no immediate build/version/AAB/Play impact. APP-08 assesses actual impact only after audits/remediation and green QA/security gates.

### Phase 4 planning handoff

- Planning gate: PASS.
- Implementation gate: NOT STARTED / not authorized by this planning pass.
- Contrast gate: PENDING execution.
- Large-text gate: PENDING execution.
- Physical TalkBack/device gate: PENDING human-host execution.
- Automated QA gate: PENDING for Phase 4 current candidate.
- Independent APP-06 QA: PENDING.
- APP-07 security/privacy: CONDITIONAL on sensitive Phase 4 source changes; Phase 3 PASS remains intact.
- APP-08 release/device impact: PENDING after QA and applicable security PASS.
- Environment-blocked gates: none at planning time; physical device/TalkBack evidence necessarily awaits human-host participation.
- P19 Phase 3: COMPLETE / QA PASS / SECURITY PASS / RELEASE-IMPACT PASS.
- P19 Phase 4: ACTIVE / PLANNING COMPLETE.
- P19 overall: OPEN.
- Exact next owner/action: `ux_workflow` creates the read-only route/state worksheet from this inventory and performs/documents the first-pass supported-light-theme contrast and 1.0/1.3/1.7/2.0 large-text UX audit; it must not modify application or test files.
