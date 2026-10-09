# In-App Feedback

## Purpose

Players and testers can report bugs and ideas without leaving the game, with an annotated screenshot of what they were looking at. Reports reach the developer as GitHub issues through a feedback worker, survive being offline, and are collected with consent, minimal data and abuse limits.

## Requirements

### Requirement: Feedback opens with an annotatable screenshot

Send feedback SHALL be reachable from the home screen and the game screen. It SHALL capture the current screen and open a sheet with a type choice (bug, feature, other), a description field and the screenshot, on which the player can draw red freehand marks. The marks SHALL be composited onto the screenshot that is sent, at the screenshot's resolution. If capture fails, the sheet SHALL still open, with a blank screenshot.

#### Scenario: Marking a bug
- GIVEN the game screen
- WHEN the player opens feedback and circles a tile on the screenshot
- THEN the submitted screenshot shows the red circle in the same place

#### Scenario: Capture fails
- GIVEN screenshot capture throws
- WHEN the player opens feedback
- THEN the sheet opens and can be submitted

### Requirement: Submission requires a real description and consent

Submit SHALL be enabled only when the trimmed description is 10 to 500 characters, the player has ticked a consent box that states exactly what is sent (type, description, annotated screenshot, app version, OS and device model), no submission is in flight and no cooldown is active. The service SHALL independently reject descriptions outside those bounds.

#### Scenario: Too short
- GIVEN a description of "bad"
- WHEN the sheet is shown
- THEN Submit is disabled

#### Scenario: No consent
- GIVEN a 40-character description and the consent box unticked
- WHEN the sheet is shown
- THEN Submit is disabled

### Requirement: Feedback is sent to the worker and signed

Submitting SHALL send the type, description, screenshot, app version, OS and a human-readable device model to the configured feedback worker, timing out after 15 seconds. When a signing secret is configured at build time, each request SHALL carry a timestamp and an HMAC-SHA256 signature over the timestamp and the exact body. A created response SHALL count as success even if its body cannot be read; a bad-request, unauthorised or forbidden response SHALL be dropped for good; any other failure SHALL be retried later.

#### Scenario: Rejected signature
- GIVEN the worker answers 401
- WHEN feedback is submitted
- THEN the report is dropped and never queued for retry

#### Scenario: Worker down
- GIVEN the worker answers 503
- WHEN feedback is submitted
- THEN the report is queued for retry

### Requirement: Unsent feedback waits offline, briefly

A report that fails retryably SHALL be kept in an encrypted, signed local queue of at most 20 reports, dropping the oldest when full. When connectivity returns, the system SHALL send the queued reports, one flush at a time, deleting each one that is sent and discarding any corrupt entry without stopping the rest. At every launch, queued reports older than 7 days SHALL be deleted. The home screen SHALL offer to clear the queue, after confirmation, reporting whether it worked.

#### Scenario: Back online
- GIVEN three queued reports, one of them corrupt
- WHEN connectivity returns
- THEN the two valid reports are sent and removed
- AND the corrupt one is discarded

#### Scenario: Stale report
- GIVEN a report queued 8 days ago
- WHEN the app starts
- THEN the report is deleted without being sent

### Requirement: Feedback is rate limited per device

The system SHALL block a submission within 30 seconds of the previous one, and after 5 submissions in a rolling hour, showing a live "Try again in N seconds" countdown while blocked. If the rate-limit record cannot be read or written, the submission SHALL be allowed.

#### Scenario: Sixth report in an hour
- GIVEN five reports sent in the last 40 minutes
- WHEN the player tries to send another
- THEN it is blocked until the hour window allows it

#### Scenario: Storage fault
- GIVEN the rate-limit storage throws
- WHEN the player submits
- THEN the submission goes ahead
