# Durable Decisions

Record only decisions that future work must preserve.

| ID | Date | Area | Decision | Rationale |
|---|---|---|---|---|
| P19-D01 | 2026-08-24 | Phase boundary | Phase 3 implementation cannot begin until Phase 2 passes focused regressions, format, analyze, full Flutter tests, and applicable guards. Read-only Phase 3 discovery may run in parallel. | Prevents compounding a known accessibility regression and preserves an auditable baseline. |
| P19-D02 | 2026-08-24 | Scope | Phase 3 is limited to app-wide screen-reader semantics, structure, traversal, dynamic announcements, transient UI, repeated content, navigation, Phase 2 form regression, and automated semantic coverage. Comprehensive contrast/large-text audit, physical TalkBack walkthrough, and final Android certification remain Phase 4. | Enforces the user-defined P19 phase boundary and avoids unrelated redesign/refactoring. |
| P19-D03 | 2026-08-24 | Data/backend | No backend, Firebase-rule, schema, storage, or migration changes are planned for Phase 3 unless a specialist identifies a genuine accessibility dependency. | The observed defects and objective are client semantics/test concerns; preserve security and data compatibility. |
| P19-D04 | 2026-08-25 | Windows QA execution | When Flutter execution is blocked solely by the managed Windows sandbox, run the reusable validation flow from host PowerShell, retain a timestamped report, and return the fresh report plus current repository state to APP-06. Host execution clears the environment block only after APP-06 independently verifies acceptance evidence, source/test state, test integrity, runtime integrity, and no unresolved QA defect. | Separates an execution-environment limitation from product quality while preserving independent QA ownership and evidence traceability. |
| P19-D05 | 2026-08-25 | Delivery status | P19 phase status follows verified implementation and gate evidence, not commit-title wording. The current `feat: P19 phase 3` title does not establish Phase 3 implementation completion. | Prevents repository metadata from overstating actual delivery progress. |
