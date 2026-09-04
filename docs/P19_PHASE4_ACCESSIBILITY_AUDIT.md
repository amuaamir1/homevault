# P19 Phase 4 - Accessibility Audit Worksheet

Status: AUTOMATED WORKSTREAM 1-2 IMPLEMENTATION PREPARED; MANUAL/DEVICE CERTIFICATION PENDING

This worksheet is tied to the HomeVault source baseline supplied on 2026-08-25.
It does not by itself certify P19. Rendered contrast, Android non-linear font
scaling, display-size interaction, transient states, and TalkBack still require
human-host evidence.

## Deterministic contrast findings remediated

| Element/token | Before | Deterministic issue | Remediation | Expected deterministic result |
|---|---:|---|---|---:|
| Secondary blue on white | `#42A5F5` | ~2.65:1; below 4.5:1 for text and below 3:1 for some essential non-text uses | `#0069A8` | ~5.86:1 on white |
| Warning amber on white | `#F9A825` | ~1.97:1; below AA for status text/icons | `#8A5D00` | ~5.76:1 on white |
| Success green on 12-14% self tint | `#2E7D32` | ~4.36-4.26:1; below 4.5:1 for small chip/status text | `#1B5E20` | >6:1 on common tints |
| Danger red on strongest common self tint | `#C62828` | close to the 4.5:1 boundary | `#B71C1C` | >5:1 on common tints |
| Secondary body text on app background | `#757575` on `#F5F7FA` | ~4.29:1; below 4.5:1 | `#616161` | ~5.77:1 |

Automated tests calculate contrast using Flutter `Color.computeLuminance()` and
exercise status text against the strongest common 14% self-tint. Rendered alpha,
elevation, images, gradients, disabled state, focus state, system UI and device
composition remain manual checks.

## Deterministic large-text/reflow findings remediated

| Surface | Finding | Remediation |
|---|---|---|
| Reports metrics | Fixed 92px row, four cards on phone-width layouts, FittedBox and ellipsis | Responsive 4/2/1-column Wrap based on width + text scale; flexible card content |
| Document Vault summary | Fixed three-card row and single-line metric labels | Responsive 3/2/1-column Wrap; labels allowed to wrap |
| Service Center summary | Fixed three-card row, 24px value slot, FittedBox and ellipsis | Responsive 3/2/1-column Wrap; flexible value/label layout |
| Warranty summary | Single horizontal scrolling pill row | Multi-row Wrap |
| Reminder summary | Single horizontal scrolling pill row | Multi-row Wrap |
| Reminder appliance identity | Essential appliance name forced to one-line ellipsis | Full wrapping title |
| Report bar | Essential label forced to one-line ellipsis | Wrapping label with flexible trailing value |

## Automated scale matrix

The automated helper/tests cover:

- 1.0 default
- 1.3 large-text threshold
- 1.7 very-large-text threshold
- 2.0 strong accessibility regression scale

The real Android default and largest-practical font settings remain required.

## Route/state manual worksheet

Complete each row on the exact validated candidate after automated validation.

| Area | Contrast | 1.0 | 1.3 | 1.7 | 2.0 | Android largest practical | Notes/evidence |
|---|---|---|---|---|---|---|---|
| Startup/authentication | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | |
| Home/navigation | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | |
| Appliances | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | |
| Warranty/AMC | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | |
| Documents | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | |
| Service center/requests | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | |
| Provider/support directory | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | |
| Reminders | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | |
| Global search | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | |
| Reports/exports | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | |
| Feedback/admin feedback | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | |
| Backup/storage | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | |
| Profile/settings/account | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | |
| Shared/transient components | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | |

## Manual contrast acceptance

For active light-theme states:

- Normal text: >= 4.5:1.
- Large-scale text: >= 3:1.
- Essential icons/control boundaries/focus/state indicators: >= 3:1.
- Selected/error/warning/success/destructive meaning must not rely on color alone.
- Text/icons over images or variable backgrounds are measured at the least
  favorable rendered point.
- Disabled controls remain visibly intentional and distinguishable from enabled
  controls.
- Dialogs, sheets, menus, snackbars, loading/error/empty states and keyboard/
  focus states are included.

P19 remains OPEN until every required manual/device row is resolved and no
critical/major finding remains.
