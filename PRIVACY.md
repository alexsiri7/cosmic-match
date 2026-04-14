# Privacy Policy: Cosmic Match — User Privacy & Data Practices

**Version:** 1.0  
**Author:** Alex  
**Status:** Active  
**Last Reviewed:** 2026-04-14

---

## 1. Overview

Cosmic Match is a space-themed match-3 puzzle game for Android. **Version 1 (V1) is fully offline** — it does not connect to the internet, does not collect personal data, and does not require any account creation. This privacy policy describes what data the app handles today and how future versions will handle data if online features are added.

---

## 2. Data We Collect (V1)

| Category | Collected? | Details |
|---|---|---|
| Personal information (name, email, etc.) | No | No account creation in V1 |
| Device identifiers | No | No tracking or analytics SDKs |
| Usage / analytics data | No | No analytics in V1 |
| Location data | No | Not requested or accessed |
| Network traffic | No | V1 makes no network requests |
| Advertising data | No | No ad SDKs in V1 |
| Payment information | No | No in-app purchases in V1 |

V1 does not collect, transmit, or share any user data.

---

## 3. Data Stored Locally

Cosmic Match V1 stores game progress on your device using Hive (a local storage library). This data includes:

- Level progress (highest level reached)
- Star ratings per level
- Game settings (sound on/off, etc.)

This data:
- Contains **no personally identifiable information (PII)**
- Contains **no unique device identifiers**
- Is stored **only on your device** — it is never transmitted
- Can be deleted by clearing the app's data or uninstalling the app

---

## 4. Permissions

| Permission | Required? | Purpose |
|---|---|---|
| INTERNET | No (debug builds only) | Used by Flutter tooling during development; not present in release builds |
| Storage | No | Hive uses app-internal storage, which requires no permission |
| Camera / Microphone | No | Not used |
| Location | No | Not used |

Cosmic Match V1 requests **no runtime permissions** in release builds.

---

## 5. Children's Privacy

Cosmic Match is suitable for all ages. Because V1 collects no data from any user — including children — there is no special data handling required. The game does not:

- Collect personal information from children (or any user)
- Include social features, chat, or user-generated content
- Display personalized advertising
- Require account creation

If future versions add features that involve data collection, we will comply with COPPA (Children's Online Privacy Protection Act) and applicable regulations, and will update this policy accordingly.

---

## 6. Future Analytics / Crash Reporting (Pre-Implementation Notice)

V1 does not include analytics or crash reporting. If a future version adds these capabilities, we will:

- Disclose the specific SDK(s) used (e.g., Firebase Crashlytics, Sentry)
- List exactly what data is collected and why
- Provide an opt-out mechanism accessible from the app's settings
- Show a **consent prompt before the first run** that includes any analytics or crash reporting
- Update this privacy policy before the release that adds these features

No analytics or crash reporting data will be collected without your knowledge and consent.

---

## 7. Future Advertising (Pre-Implementation Notice)

V1 does not include advertising. If a future version adds ads, we will:

- Comply with GDPR and CCPA consent requirements
- Display a **consent dialog** before showing any ads
- Not show personalized ads without explicit opt-in consent
- Provide a way to change your ad preferences at any time in the app's settings
- Comply with Google Families Policy if the game is listed in the "Family" category
- Update this privacy policy before the release that adds advertising

---

## 8. Data Minimisation Principle

Cosmic Match follows a strict data minimisation principle:

- We collect **only** data that is strictly necessary for a stated feature
- We do not collect data "just in case" or for undefined future use
- Any data collection will be clearly documented in this policy before it begins
- Users may request deletion of any stored data at any time

---

## 9. Your Rights

Regardless of where you are located, you have the right to:

| Right | Description |
|---|---|
| Access | Request a copy of any data we hold about you |
| Deletion | Request deletion of any data we hold about you |
| Portability | Request your data in a portable format |
| Objection | Object to data processing for specific purposes |
| Withdraw consent | Withdraw previously granted consent at any time |

For V1, these rights are satisfied automatically — no personal data is collected or stored. If future versions collect data, we will provide mechanisms to exercise these rights within the app or via the contact method below.

**GDPR (EU):** We will appoint a data protection contact and respond to requests within 30 days.  
**CCPA (California):** We will not sell personal information. You may opt out of any data sharing.

---

## 10. Contact

For privacy-related questions or data requests:

- **Email:** privacy@cosmicmatch.com *(placeholder — not yet active)*
- **GitHub Issues:** File an issue in the Cosmic Match repository

---

## 11. Changes to This Policy

If we make changes to this privacy policy, we will:

- Update the **"Last Reviewed"** date at the top of this document
- For V1 (offline, no data collection): changes are communicated via the updated date above
- For future versions that collect data: show an in-app notice on the next app launch after a policy change
- For material changes (e.g., adding data collection), require renewed consent before proceeding

---

## 12. Effective Date

This policy is effective as of **2026-04-14**.

---

## 13. Cross-References

- **Security practices:** See `SECURITY.md` for the internal developer security checklist, including §9 (Data Privacy) and §10 (Pre-Backend-Launch Checklist).
- **Product requirements:** See `prd.md` §11 (Milestones) for the M5 shipping checklist that references this policy.
