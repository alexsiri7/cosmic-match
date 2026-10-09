# Screens and Theme

## Purpose

Cosmic Match is a glanceable space-themed game for short sessions. Its screens must reinforce the cosmic identity, make every tile recognisable at a glance by shape as well as colour, and fit any Android phone or tablet in portrait.

## Requirements

### Requirement: The app opens on the home screen

The app SHALL open on the home screen, which offers Play, the galaxy map and Send feedback. Play SHALL open the game screen, and the game screen's back control SHALL return to the home screen without discarding the game in progress.

#### Scenario: Leave and come back
- GIVEN a game with score 240
- WHEN the player goes back to the home screen and taps Play again
- THEN the same board is shown with score 240

### Requirement: Every screen uses the cosmic theme

Every screen SHALL use the cosmic palette: a deep-ink background with nebula gradients and a starfield, a dark board backdrop and grid lines. These colours SHALL come from one set of shared theme tokens. The home starfield SHALL be the same on every render.

#### Scenario: Consistent look
- GIVEN the home screen, the game screen and a result screen
- WHEN each is shown
- THEN each uses the same ink background and nebula colours

### Requirement: Tiles differ by shape and colour

Each of the six tile types — red planet, blue ringed planet, yellow star, purple nebula, white moon, orange comet — SHALL have its own shape and its own colour and glow, so no two types can be told apart by colour alone.

#### Scenario: Colour-blind player
- GIVEN a board showing all six tile types
- WHEN it is viewed in greyscale
- THEN every type is still identifiable by its shape

### Requirement: The board fits any screen in portrait

The app SHALL run in portrait orientation only and SHALL NOT rotate to landscape. The board SHALL size its tiles to fit the width and the space below the header, centre itself, and relayout every tile when the screen size changes, so it is never cropped on phones, 7-inch or 10-inch tablets.

#### Scenario: Rotating the device
- GIVEN the game screen is open
- WHEN the device is turned sideways
- THEN the app stays in portrait

#### Scenario: Tablet
- GIVEN a 10-inch tablet
- WHEN the game screen is shown
- THEN the whole 8 by 8 board is visible and centred
