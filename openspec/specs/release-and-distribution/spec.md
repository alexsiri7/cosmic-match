# Release and Distribution

## Purpose

The goal is a polished game on the Google Play Store. Releases must be signed and reproducible with secrets kept out of the repository, every change must pass automated checks first, store imagery must match the real game, and players must receive updates without being interrupted.

## Requirements

### Requirement: The game targets Android and needs almost nothing

The game SHALL run on Android 8 (API 26) and later, SHALL request no permission other than internet access, and SHALL work without accounts, a backend or leaderboards.

#### Scenario: Install
- GIVEN an Android 8 device
- WHEN the game is installed
- THEN the only permission requested is internet access

### Requirement: Configuration is injected at build time

The crash-reporting DSN, the feedback worker address and the feedback signing secret SHALL be supplied only at build time and SHALL NOT be written in the source, apart from the default worker address. A build supplied with none of them SHALL still produce a playable game, with crash reporting off and feedback sent unsigned.

#### Scenario: Bare build
- GIVEN a build with no configuration supplied
- WHEN the game is run
- THEN it plays normally

### Requirement: Releases are signed, obfuscated and free of repository tokens

A release SHALL be a signed Android App Bundle, also built as an APK, with code obfuscated and debug symbols split out. Signing credentials SHALL come only from a local file excluded from the repository, documented by an example file, or from CI secrets. Debug symbols SHALL be uploaded for crash reporting when an upload token is present, and skipped, not failed, when it is not. The release build SHALL fail if a GitHub token is present in its environment.

#### Scenario: Token leak guard
- GIVEN a GitHub token is visible to the release build
- WHEN the release runs
- THEN the build fails

#### Scenario: No symbol token
- GIVEN no symbol upload token
- WHEN the release runs
- THEN the bundle is built and symbol upload is skipped

### Requirement: Every change passes checks before release

Every proposed change SHALL pass static analysis, the unit, widget and golden-image tests, and the integration tests on an Android emulator. Dependency changes SHALL commit the updated lockfile with them so builds are reproducible.

#### Scenario: Visual regression
- GIVEN a change that alters how a fresh board renders
- WHEN checks run
- THEN the golden-image test fails

### Requirement: Store screenshots come from the real UI

On request, the system SHALL regenerate the phone, 7-inch and 10-inch store screenshots from the game's own rendering tests and propose them as a change to the store listing, proposing nothing when they are unchanged.

#### Scenario: UI unchanged
- GIVEN the rendered screenshots match the stored ones
- WHEN regeneration is requested
- THEN no change is proposed

### Requirement: Updates install without interrupting play

On Android, when a newer version is available on the Play Store, the app SHALL download it in the background and then show a lasting "Update ready" notice with a Restart action that installs it. A failure anywhere in the update check SHALL NOT affect the game.

#### Scenario: Update downloaded
- GIVEN a newer version finishes downloading
- WHEN the player is on any screen
- THEN an "Update ready" notice with Restart is shown until acted on

#### Scenario: Update check fails
- GIVEN the Play Store cannot be reached
- WHEN the app starts
- THEN the game starts normally
