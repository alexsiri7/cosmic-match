# Board and Matching

## Purpose

The board is the whole game: the player swaps adjacent tiles, lines of three or more of a kind clear, the rest fall and the board refills. Every move must resolve to a settled, fully packed board, and the player must never be able to act on a board that is still moving.

## Requirements

### Requirement: A new board is full and quiet

When a game session starts, the system SHALL present an 8 by 8 grid with every cell filled by one of the six tile types, and SHALL NOT present a match of three or more. Board generation SHALL be bounded so that an unlucky draw still yields a full board rather than hanging.

#### Scenario: Fresh board
- GIVEN a new game session
- WHEN the board appears
- THEN it has 8 columns and 8 rows with no empty cell
- AND no row or column holds three or more matching tiles in a line

### Requirement: Tiles are selected by tapping

While the board is idle, tapping a tile SHALL select it and mark it with a glowing border rather than a filled overlay. Tapping the selected tile again SHALL deselect it. Tapping a tile that is not orthogonally adjacent SHALL move the selection to that tile.

#### Scenario: Select, then change mind
- GIVEN no tile is selected
- WHEN the player taps tile A and then a tile two cells away
- THEN tile A is deselected
- AND the second tile is selected with a glowing border

#### Scenario: Deselect
- GIVEN tile A is selected
- WHEN the player taps tile A again
- THEN no tile is selected

### Requirement: Adjacent tiles are swapped by tap or swipe

Tapping a tile orthogonally adjacent to the selected tile SHALL clear the selection and swap the two. Swiping on a tile SHALL swap it with its neighbour in the swipe direction and SHALL clear any pending tap selection. Diagonal taps, and swipes off the board edge, SHALL NOT swap anything.

#### Scenario: Tap-to-swap
- GIVEN tile A is selected
- WHEN the player taps the tile directly to its right
- THEN the two tiles swap and nothing remains selected

#### Scenario: Swipe off the edge
- GIVEN a tile on the top row
- WHEN the player swipes it upward
- THEN nothing happens

### Requirement: A swap that makes no match is undone

When a swap produces no match, the system SHALL animate both tiles back to their original cells, restore the board, return to idle and award no points.

#### Scenario: Invalid swap
- GIVEN two adjacent tiles whose swap forms no line of three
- WHEN the player swaps them
- THEN both tiles return to where they were
- AND the score is unchanged and the board accepts input again

### Requirement: Matches clear, tiles fall and the board refills

When a swap or cascade produces three or more same-type tiles in a contiguous row or column, the system SHALL remove them. Remaining tiles SHALL then fall straight down within their columns, keeping their order, and every empty cell SHALL be refilled with a random tile that drops in from above the board, leaving the board fully packed.

#### Scenario: Clear and refill
- GIVEN a swap that lines up three stars in a column
- WHEN the match resolves
- THEN the three stars are removed
- AND the tiles above them drop down in the same order
- AND new tiles fall in from above until no cell is empty

### Requirement: Cascades chain, with a bounded depth

When a refill produces new matches, the system SHALL clear them and repeat the fall-and-refill cycle without further player input, counting each repetition as one cascade level. Cascading SHALL stop after 20 levels even if matches remain, and the board SHALL then return to idle.

#### Scenario: Chain reaction
- GIVEN a refill that lines up three moons
- WHEN the board settles
- THEN the moons clear on their own and the board refills again

#### Scenario: Runaway cascade
- GIVEN a sequence that would keep producing matches forever
- WHEN the cascade reaches 20 levels
- THEN cascading stops and the board accepts input

### Requirement: Input is accepted only on a settled board

The game SHALL move only along its legal phases: idle to swapping; swapping to matching or back to idle; matching to falling; falling to cascading or idle; cascading to matching. A cascade SHALL end by passing through matching and falling, never straight to idle. While the phase is anything other than idle, all taps and swipes on tiles SHALL be ignored. An illegal phase change SHALL stop a debug build and SHALL return a release build to idle so the game is never stuck.

#### Scenario: Tapping during a cascade
- GIVEN tiles are falling
- WHEN the player taps or swipes a tile
- THEN the selection does not change and no swap starts

#### Scenario: Recovering from an unexpected error
- GIVEN a release build
- WHEN a swap or cascade fails unexpectedly
- THEN the game returns to idle and accepts input
