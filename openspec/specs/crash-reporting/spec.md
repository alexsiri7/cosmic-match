# Crash Reporting

## Purpose

Release builds can crash in ways that never reproduce locally. Crash reporting captures those failures without personal data, never stands in the way of launching the game, and filters out known noise so real crashes stand out.

## Requirements

### Requirement: Crash reporting is opt-in at build time

When a crash-reporting DSN is supplied at build time, the system SHALL report crashes tagged with the environment (release or debug) and a release identifier of package name, version and build number. When no DSN is supplied, or crash reporting fails to start, the app SHALL launch normally with crash reporting off.

#### Scenario: No DSN
- GIVEN a build with no DSN
- WHEN the app starts
- THEN it launches and no crash reporting is attempted

#### Scenario: Initialisation fails
- GIVEN crash reporting throws while starting
- WHEN the app starts
- THEN the app still launches

### Requirement: Crash reports carry no personal data

While crash reporting is on, the system SHALL NOT send personal data or screenshots and SHALL NOT collect performance traces. In release builds, framework debug output SHALL be silenced, and logs SHALL never contain feedback text or screenshots.

#### Scenario: A crash in release
- GIVEN crash reporting is on
- WHEN the app crashes
- THEN the report contains no personal data and no screenshot

### Requirement: Known unactionable events are dropped

Before sending, the system SHALL drop exactly these known-noise events: a lone "Abort" whose stack frames are all in the platform channel buffers; a lone "Abort" whose frames are all native system calls; and a failure to download a web font. Any other event, including an "Abort" with no frames, mixed frames or several exceptions, SHALL be sent unchanged.

#### Scenario: Font download failure
- GIVEN a font fetch fails while offline
- WHEN the event is captured
- THEN it is not sent

#### Scenario: Abort without frames
- GIVEN an "Abort" event with no stack frames
- WHEN the event is captured
- THEN it is sent
