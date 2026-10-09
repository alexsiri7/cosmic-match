# Save Integrity

## Purpose

Progress and queued feedback live only on the device. They must survive restarts, must not be readable at rest, and must not be trivially edited to fake progress — without any server and without ever crashing the game when something goes wrong.

## Requirements

### Requirement: Local data is encrypted at rest

The system SHALL store level progress and the feedback queue in encrypted local storage, using an AES-256 key generated once per install and kept in platform secure storage. The same key SHALL be used on every later launch. When secure storage is unavailable, the app SHALL still launch and play, without persisting.

#### Scenario: Restart keeps progress
- GIVEN a player with stored progress
- WHEN the app is closed and reopened
- THEN the same progress is loaded

#### Scenario: Secure storage fails
- GIVEN platform secure storage throws on access
- WHEN the app starts
- THEN the app launches and the game is playable

### Requirement: Stored records are signed and tampering is detected

Every stored record SHALL carry an HMAC-SHA256 signature over all its other fields in a key-sorted canonical form, using a device-local key. A record with a missing or wrong signature SHALL be treated as tampered: level progress SHALL reset to its initial values and a feedback-queue entry SHALL be discarded. When no signing key is available, saves SHALL be skipped and every loaded record SHALL be treated as invalid. A plain checksum SHALL NOT be used, because it can be forged.

#### Scenario: Edited save file
- GIVEN a stored best score edited outside the app
- WHEN progress is loaded
- THEN progress resets to the initial state with best score 0

#### Scenario: Unreadable storage
- GIVEN stored data that cannot be decrypted with the current key
- WHEN progress is loaded
- THEN progress resets to the initial state and the app does not crash
