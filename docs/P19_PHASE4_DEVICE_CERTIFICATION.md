# P19 Phase 4 - Android TalkBack and Device Certification

This is the human-host acceptance checklist for the exact candidate that passes
the P19 Phase 4 automated validator.

## Record environment identity

- Tester:
- Date/time/time zone:
- Git branch:
- Git HEAD:
- Working-tree/source ZIP or hash:
- Build type:
- App version/build:
- APK/AAB identity if applicable:
- Device/AVD:
- Architecture:
- Android version/API:
- Resolution/density/orientation:
- Android font setting:
- Android display-size setting:
- TalkBack / Android Accessibility Suite version:
- Flutter version:
- Dart version:
- Connectivity:
- Test account role/data profile:
- External/hardware keyboard used: yes/no

Do not record passwords, PINs, tokens, private document contents, private local
paths, or other sensitive user data.

## Common TalkBack checks

For every journey confirm:

- Every actionable control has a useful name and correct role/state.
- Swipe order follows the visual/task order.
- Explore-by-touch does not expose duplicate or hidden actionable nodes.
- Route changes, dialogs, sheets and menus receive sensible focus.
- Back/cancel restores usable focus.
- Loading, validation and outcome changes are announced once and without private
  data leakage.
- Selected/checked/expanded/disabled state is announced where applicable.
- Destructive actions clearly announce consequence before confirmation.
- No essential workflow requires color, exact visual position, or sight.

## Critical journeys

| ID | Journey | Result | Evidence/notes |
|---|---|---|---|
| A | Authentication/PIN: sign in, password visibility, recovery/error, PIN create/login, lock/recovery, sensitive verification | PENDING | |
| B | Main navigation: Home / Service center / Support / Settings, headings, metrics, badges and focus restoration | PENDING | |
| C | Appliances: browse repeated rows, search/filter/sort, add/edit, details/images/actions, destructive cancel/confirm | PENDING | |
| D | Warranty/AMC: browse/filter/sort, appliance identity, status/dates/countdowns/reminders/actions without color reliance | PENDING | |
| E | Documents: duplicate titles, filters, add/select attachment, details/open/export/Save a copy, menus/errors/delete confirmation/privacy | PENDING | |
| F | Service: repeated records, add/edit, requests, provider prefill, status sheet, details, validation/error/delete | PENDING | |
| G | Global search: enter/clear, result-count announcement, grouped/repeated results, empty/error, activate/return focus | PENDING | |
| H | Feedback: user submission; authorized admin dashboard/filter/sort/status/repeated entries/details/images/private values | PENDING | |
| I | Backup/restore/cloud: local backup, support pack, cloud history, device storage, selections, progress/errors/destructive confirmations | PENDING | |
| J | Account/deletion: profile/settings/security/account data, switches/selectors, sign out, deletion/re-auth/cancel; final delete only disposable account | PENDING | |

## Actual Android large-font/device checks

Run at both default and largest practical supported Android font settings.
Record the displayed setting rather than assuming it equals Flutter linear 2.0.

Confirm:

- No clipped glyphs or RenderFlex/viewport overflow.
- No overlapping controls.
- Focused form fields, validation messages and submit/cancel actions remain
  reachable with the keyboard open.
- Dialogs/bottom sheets remain scrollable and all actions reachable.
- Bottom navigation destinations remain understandable and actionable.
- Long appliance/document/provider/service/feedback values remain distinguishable.
- No essential name/value/status/destructive consequence is hidden only by
  ellipsis.
- Display-size changes do not strand a primary action.

## Certification result

- Contrast worksheet: PENDING
- 1.0/1.3/1.7/2.0 automated evidence: PENDING
- Android default/largest-practical font evidence: PENDING
- TalkBack A-J: PENDING
- Current-tree automated validator: PENDING
- Independent QA/review: PENDING
- Security/privacy rerun: REQUIRED only if final Phase 4 changes touch sensitive
  data/announcements/permissions/destructive flows; otherwise retain Phase 3 PASS
- Final release/device-impact review: PENDING

P19 Phase 4 / P19 overall must not be marked COMPLETE until all required gates
are PASS or a genuinely inapplicable item is documented N/A with rationale.
