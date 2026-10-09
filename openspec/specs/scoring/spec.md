# Scoring

## Purpose

The score tells the player how well they are doing and rewards chains. It is shown live on the game screen, and the player's best is kept across sessions.

## Requirements

### Requirement: Points reward tiles cleared and cascade depth

For every match cleared, the system SHALL award 10 points per tile multiplied by one plus half the current cascade level, rounded to the nearest whole point, and SHALL show the new score on the game screen in the same step.

#### Scenario: Basic match
- GIVEN no cascade is in progress
- WHEN a three-tile match clears
- THEN 30 points are added

#### Scenario: Deep in a cascade
- GIVEN the cascade is at level 2
- WHEN a three-tile match clears
- THEN 60 points are added

### Requirement: The score cannot be pushed out of range

Adding zero or negative points SHALL leave the score unchanged, and the score SHALL never exceed 999,999,999.

#### Scenario: Overflow attempt
- GIVEN a score of 999,999,990
- WHEN 100 points are added
- THEN the score is exactly 999,999,999

#### Scenario: Negative input
- GIVEN any score
- WHEN -100 points are added
- THEN the score is unchanged

### Requirement: The best score is kept and shown

The game screen SHALL show both the current score and the best score for the level. When a move's cascade ends with a score above the stored best, the system SHALL store the new best so it survives restarting the app; a lower score SHALL NOT overwrite it.

#### Scenario: New best
- GIVEN a stored best of 500
- WHEN a cascade ends with the score at 620
- THEN the best shows 620
- AND after restarting the app the best still shows 620

#### Scenario: Below best
- GIVEN a stored best of 500
- WHEN a cascade ends with the score at 300
- THEN the stored best remains 500
