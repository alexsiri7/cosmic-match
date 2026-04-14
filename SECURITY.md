# Security Guide: Cosmic Match — Backend Security Requirements

**Version:** 1.0  
**Author:** Alex  
**Status:** Draft  
**Last Reviewed:** 2026-04-14

---

## 1. Current Security Posture (V1)

Cosmic Match V1 is a **fully offline** game. The current security surface is minimal:

| Aspect | Status |
|---|---|
| Network access | None in release builds |
| INTERNET permission | Debug-only (Flutter tooling) |
| Data storage | Local-only via Hive (encryption key infrastructure in place; cipher wiring deferred to M2) |
| Authentication | None |
| Permissions requested | None beyond default |

The main `AndroidManifest.xml` declares no permissions. The `INTERNET` permission exists only in `android/app/src/debug/AndroidManifest.xml` for Flutter hot reload and debugging — it is **not** included in release builds.

### 1.1 Client-Side Integrity Controls (SEC-008)

Four mitigations are implemented in M1 to make trivial client-side manipulation harder.
They do not stop a determined attacker on a rooted device, but raise the effort bar and
will become more meaningful when leaderboards are added (see §2).

| Control | Implementation | Limit |
|---------|---------------|-------|
| FSM Input Gate | `GridTile.onTapDown` drops all taps when `game.phase != idle` | Prevents tap injection during animations |
| Score Clamp | `Score.add()` ignores non-positive inputs and clamps to 999,999,999 | Prevents integer overflow exploits |
| Cascade Depth Limit | `CascadeController.maxDepth = 20`; `increment()` is a no-op once cap is reached | Prevents infinite cascade loops from bugs in gravity/refill logic |
| CRC32 Save Integrity | `LevelProgress.toMap()` stores a CRC32 over canonicalized (key-sorted) fields; `ProgressService._isValid()` resets tampered data to `LevelProgress.initial()` | Deters hex-editor score edits; not cryptographically secure |

**Note**: If leaderboards are added (post-V1), SEC-008 risk level rises to MEDIUM. Server-side score validation will be required at that point — see §2.

### 1.2 Hive Encryption at Rest (SEC-004)

`KeyService` generates a 32-byte AES-256 key on first launch and stores it in the Android
Keystore via `flutter_secure_storage`. `ProgressService` accepts an optional `HiveAesCipher`
and passes it to `Hive.openBox()`, rendering the on-disk box opaque ciphertext. If the
Keystore is unavailable (emulator, broken hardware), `getCipher()` returns `null` and the
box opens unencrypted — the CRC32 integrity layer (SEC-008) still applies.

**Status**: Infrastructure complete. Game-layer wiring (passing the cipher from `main()`
through the Riverpod provider tree to `ProgressService`) is deferred to M2.

---

## 2. Scope of This Document

This document applies **only when backend features are introduced** (post-V1). Relevant future features from the PRD include:

- Leaderboards
- Daily challenge levels
- Optional rewarded ads / monetisation
- Cloud sync

Until one of these features is implemented, no action is required. When backend work begins, this document serves as the security checklist and architecture guide.

---

## 3. Authentication

### 3.1 Provider Comparison

| Criteria | Firebase Auth | Supabase Auth |
|---|---|---|
| Flutter SDK maturity | Mature, first-party | Actively maintained by Supabase; slightly less Flutter-ecosystem integration than Firebase |
| Social auth (Google, Apple) | Built-in | Built-in |
| Self-hosting | No | Yes (Docker) |
| Vendor lock-in | High (Google ecosystem) | Low (open source, PostgreSQL) |
| Pricing at scale | Pay-as-you-go, can spike | Predictable tiers, free self-hosted |
| Data sovereignty | Google-managed regions | Full control if self-hosted |
| Offline support | Good (cached credentials) | Limited |

### 3.2 Decision Criteria

Choose **Firebase Auth** if:
- You want the fastest integration path with Flutter
- Google ecosystem services (Analytics, Crashlytics) are also planned
- Offline credential caching is important

Choose **Supabase Auth** if:
- Data sovereignty or self-hosting is a requirement
- You want to avoid vendor lock-in
- The backend will use PostgreSQL (Supabase provides a full Postgres database)

### 3.3 Requirements (Either Provider)

- Support social sign-in (Google) — strongly recommended to reduce sign-up friction; Apple Sign-In is required on iOS (App Store rule) if any other social provider is offered
- Implement account deletion — required for Play Store compliance (apps with account creation must offer deletion)
- Support anonymous/guest accounts for players who do not want to sign in
- Store auth tokens securely using `flutter_secure_storage`, never in plain Hive boxes
- Implement token refresh logic with exponential backoff
- Add a sign-out flow that clears local credentials

---

## 4. Android Network Security

### 4.1 Background

Android 9+ (API 28+) blocks cleartext HTTP by default. Since `minSdk = 26` (Android 8), the app spans both behaviours. A `network_security_config.xml` must be created when any network calls are added.

### 4.2 Network Security Config Template

Create `android/app/src/main/res/xml/network_security_config.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <!-- Block all cleartext (HTTP) traffic in production -->
    <base-config cleartextTrafficPermitted="false">
        <trust-anchors>
            <certificates src="system" />
        </trust-anchors>
    </base-config>

    <!-- Optional: pin certificates for your API domain -->
    <!--
    <domain-config>
        <domain includeSubdomains="true">api.cosmicmatch.com</domain>
        <!-- Set expiration at least 2 years from today. Schedule a calendar reminder
             to rotate pins and update this date before it expires. -->
        <pin-set expiration="2028-04-01">
            <pin digest="SHA-256">YOUR_PIN_HASH_HERE</pin>
            <pin digest="SHA-256">YOUR_BACKUP_PIN_HASH_HERE</pin>
        </pin-set>
    </domain-config>
    -->
</network-security-config>
```

Reference it in `android/app/src/main/AndroidManifest.xml`:

```xml
<application
    android:networkSecurityConfig="@xml/network_security_config"
    ...>
```

### 4.3 Certificate Pinning

Certificate pinning is recommended for production API endpoints. Always include a backup pin. Set an expiration date and rotate pins before expiry.

---

## 5. API Security

### 5.1 Rate Limiting

| Endpoint Type | Recommended Limit |
|---|---|
| Auth (login/register) | 5 requests per minute per IP |
| Leaderboard submit | 10 requests per minute per user |
| Leaderboard read | 30 requests per minute per user |
| Daily challenge fetch | 5 requests per minute per user |

Implement rate limiting server-side. Firebase provides App Check for abuse prevention. Supabase supports rate limiting via PostgreSQL policies or a reverse proxy (e.g., Nginx, Cloudflare).

### 5.2 CORS Configuration

If the backend exposes a REST API that may be called from a web client:

```
Access-Control-Allow-Origin: https://cosmicmatch.com
Access-Control-Allow-Methods: GET, POST
Access-Control-Allow-Headers: Authorization, Content-Type
Access-Control-Max-Age: 86400
```

Do **not** use `Access-Control-Allow-Origin: *` in production.

### 5.3 Security Headers

All backend HTTP responses must include:

| Header | Value | Purpose |
|---|---|---|
| `Strict-Transport-Security` | `max-age=63072000; includeSubDomains; preload` | Enforce HTTPS |
| `Content-Security-Policy` | `default-src 'self'` | Prevent XSS |
| `X-Content-Type-Options` | `nosniff` | Prevent MIME sniffing |
| `X-Frame-Options` | `DENY` | Prevent clickjacking |
| `Referrer-Policy` | `strict-origin-when-cross-origin` | Limit referrer leakage |

---

## 6. Secrets Management

### 6.1 Rules

- **Never** hardcode API keys, secrets, or credentials in source code
- **Never** commit `.env` files, keystores, or `key.properties` to the repository
- Use environment variables or a secrets manager for all sensitive values

### 6.2 `.gitignore` Coverage

The repository `.gitignore` already excludes:

```
*.jks
*.keystore
key.properties
.env
.env.*
*.env
```

When adding a backend, verify these entries remain in place.

### 6.3 Environment Variable Pattern

Create a `.env.example` (committed) documenting required variables without real values:

```
# Backend API
API_BASE_URL=https://api.cosmicmatch.com
API_KEY=YOUR_API_KEY_HERE

# Firebase (if used)
FIREBASE_PROJECT_ID=YOUR_PROJECT_ID_HERE
FIREBASE_API_KEY=YOUR_FIREBASE_API_KEY_HERE

# Supabase (if used)
SUPABASE_URL=YOUR_SUPABASE_URL_HERE
SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY_HERE
```

Use `--dart-define` or `--dart-define-from-file` to inject values at build time:

```bash
flutter build apk \
  --dart-define=API_KEY=... \
  --dart-define=API_BASE_URL=...
```

Or with a file (Flutter 3.17+):
```bash
flutter build apk --dart-define-from-file=.env
```

Values passed via `--dart-define` are compiled into the binary and are not bundled as extractable text assets. Never commit actual `.env` files to the repository.

> ⚠️ Do **not** use `flutter_dotenv` in release builds — it bundles the `.env` file into the APK's assets directory, where it can be extracted from a downloaded APK.

---

## 7. Flutter Integration Patterns

### 7.1 Repository Pattern

Follow the existing `ProgressRepository` pattern when adding backend repositories. New classes should use constructor injection and clear method signatures with doc comments:

```dart
/// Repository for authenticating users and managing sessions.
class AuthRepository {
  final AuthClient _client;

  AuthRepository({required AuthClient client}) : _client = client;

  /// Sign in with Google and return the user profile.
  Future<UserProfile> signInWithGoogle() async {
    // ...
  }

  /// Sign out and clear local credentials.
  Future<void> signOut() async {
    // ...
  }
}
```

### 7.2 Initialisation Pattern

Follow `main.dart`'s async initialisation pattern. Initialise auth and network clients before `runApp()`:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Existing Hive init...
  await Hive.initFlutter();

  // New: initialise auth client
  final authClient = await AuthClient.initialize();
  authRepository = AuthRepository(client: authClient);

  // New: initialise API client
  apiRepository = ApiRepository(baseUrl: Environment.apiBaseUrl);

  runApp(const CosmicMatchApp());
}
```

---

## 8. Code Signing

### 8.1 Current State

`android/app/build.gradle.kts` contains:

```kotlin
// TODO: Add your own signing config for the release build.
// Signing with the debug keys for now
signingConfig = signingConfigs.getByName("debug")
```

### 8.2 Production Signing Requirements

Before publishing to the Play Store:

1. Generate a production keystore: `keytool -genkey -v -keystore cosmic-match-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias cosmic-match`
2. Store the keystore **outside** the repository (never commit it)
3. Create `android/key.properties` (gitignored) with:
   ```
   storePassword=YOUR_STORE_PASSWORD_HERE
   keyPassword=YOUR_KEY_PASSWORD_HERE
   keyAlias=cosmic-match
   storeFile=/path/to/cosmic-match-release.jks
   ```
4. Reference `key.properties` in `build.gradle.kts` for the release signing config
5. For CI/CD, store the keystore as a Base64-encoded GitHub Secret and decode it during the build step

### 8.3 Play App Signing

Enrol in Google Play App Signing. This lets Google manage the app signing key while you use an upload key — reducing the risk of a lost keystore locking you out of updates.

---

## 9. Data Privacy

### 9.1 Current State (V1)

- All data is stored locally on-device via Hive
- No data is transmitted over the network
- No personal information is collected

### 9.2 When a Backend Is Added

- Create a Privacy Policy (required for Play Store)
- Implement data export (GDPR right of access)
- Implement account deletion (GDPR right to erasure, Play Store requirement)
- Log only what is necessary — no PII in server logs
- Encrypt data in transit (TLS 1.2+) and at rest

---

## 10. Pre-Backend-Launch Checklist

Complete all items before shipping any backend-connected release:

| # | Checkpoint | Status |
|---|---|---|
| 1 | Production keystore generated and stored securely (not in repo) | [ ] |
| 2 | `key.properties` created and gitignored | [ ] |
| 3 | `network_security_config.xml` created with cleartext blocked | [ ] |
| 4 | Auth provider selected and integrated (Firebase or Supabase) | [ ] |
| 5 | Auth tokens stored via `flutter_secure_storage` | [ ] |
| 6 | Rate limiting configured on all API endpoints | [ ] |
| 7 | CORS restricted to known origins | [ ] |
| 8 | Security headers (HSTS, CSP, X-Frame-Options) set on backend | [ ] |
| 9 | No secrets in source code — verified via `git secrets` or pre-commit hook | [ ] |
| 10 | `.env.example` created with placeholder values only | [ ] |
| 11 | Privacy Policy published and linked in Play Store listing | [ ] |
| 12 | Account deletion flow implemented (Play Store requirement) | [ ] |
| 13 | TLS 1.2+ enforced for all API communication | [ ] |
| 14 | Certificate pinning configured with backup pin | [ ] |
| 15 | This document reviewed and updated for the chosen architecture | [ ] |
