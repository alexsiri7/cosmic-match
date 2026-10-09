# Levels and Progression

## Purpose

Levels give each session a goal and a light sense of pressure, and the galaxy map lets the player see how far they have come and choose where to play. Progress is earned level by level and kept on the device.

## Requirements

### Requirement: Each level has a goal and a move limit

Every level SHALL define a goal, such as clearing a number of a given tile type or reaching a score, and a move limit. The game screen SHALL show the level's name, its goal with current progress toward it, and the moves remaining. Each valid swap SHALL use one move; a swap that is undone SHALL NOT.

#### Scenario: Starting a level
- GIVEN a level whose goal is to clear 30 red planets in 20 moves
- WHEN the player starts it
- THEN the game screen shows the goal, 0 of 30 cleared, and 20 moves left

#### Scenario: Undone swap costs nothing
- GIVEN 12 moves left
- WHEN the player makes a swap that forms no match
- THEN 12 moves are still left

### Requirement: Levels are won or lost

When the goal is met, the level SHALL end as complete, once the board has settled, and show the stars earned, the score, and choices to go to the next level or replay. When the moves run out with the goal unmet, the level SHALL end as failed and show the score with choices to retry or return to the galaxy map.

#### Scenario: Goal met
- GIVEN a level one tile short of its goal
- WHEN a match clears that tile
- THEN once the board settles the level-complete screen shows stars, score, Next Level and Replay

#### Scenario: Out of moves
- GIVEN one move left and the goal unmet
- WHEN the last move resolves without meeting the goal
- THEN the level-failed screen shows the score, Retry and Galaxy map

### Requirement: Completing a level earns one to three stars

A completed level SHALL award one to three stars based on the score or the moves remaining. The system SHALL keep, per level, the most stars and the best score ever earned, and a later worse result SHALL NOT lower either.

#### Scenario: Replaying for more stars
- GIVEN level 3 is stored with 1 star
- WHEN the player completes it again with 3 stars
- THEN level 3 is stored with 3 stars

### Requirement: The galaxy map shows progress and unlocks levels

The system SHALL offer a galaxy map, reachable from the home screen and from the level-failed screen, listing the levels grouped into galaxies of ten. Each level SHALL show whether it is locked and the stars earned. The first level SHALL be unlocked from the start, and completing a level SHALL unlock the next. Choosing an unlocked level SHALL start it; a locked level SHALL NOT start.

#### Scenario: Unlocking the next level
- GIVEN level 4 is locked
- WHEN the player completes level 3
- THEN level 4 is shown unlocked on the galaxy map

#### Scenario: Locked level
- GIVEN level 9 is locked
- WHEN the player chooses it on the map
- THEN it does not start

### Requirement: The home screen resumes where the player left off

The home screen SHALL offer to play the furthest unlocked level, showing its name, galaxy and stars earned from stored progress.

#### Scenario: Returning player
- GIVEN the player has unlocked up to level 7 and earned 2 stars on it
- WHEN they open the app
- THEN the home screen offers Play level 7 and shows 2 stars

### Requirement: A level can be paused

The game screen SHALL offer a pause control that stops play and offers to resume, restart the level, or leave to the home screen. While paused, the board SHALL accept no input.

#### Scenario: Pause and resume
- GIVEN a level in progress
- WHEN the player pauses and then resumes
- THEN the board, score and moves are exactly as they were
