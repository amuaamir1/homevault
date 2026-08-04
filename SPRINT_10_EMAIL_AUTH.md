# Sprint 10 — Email Authentication Migration

Release: **HomeVault Beta R04**  
Version: **1.12.0+15**

## Delivered

- Reference-style blue HomeVault authentication screen.
- Log In and Register tabs.
- Email/password account creation.
- Firebase email-verification link and resend/check controls.
- Password-reset email.
- Mobile number moved to editable profile details.
- HomeVault PIN required for normal returning access.
- Email/password required after explicit sign-out.
- Existing PIN preserved during sign-out.
- Password-based forgotten-PIN recovery.
- Legacy active phone-auth account upgrade using Firebase credential linking.

## Expected first-time flow

```text
Register → Verify email → Create PIN → Complete profile → Dashboard
```

## Expected returning flow

```text
App reopened with active Firebase session → PIN/biometric → Dashboard
```

## Expected post-logout flow

```text
Log in with email/password → Dashboard → Later app opens use PIN
```
