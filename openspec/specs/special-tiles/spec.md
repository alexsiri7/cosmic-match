# Special Tiles

## Purpose

Plain three-in-a-row gets repetitive fast. Bigger matches create special tiles — Pulsar, Black Hole and Supernova — that add strategy and spectacle when they are later matched.

## Requirements

### Requirement: Patterns are recognised in strict priority

When matches are detected, the system SHALL classify them in this order: five in a row as Supernova; an L or T shape of five or more tiles formed by a horizontal and a vertical run of three or more sharing a tile as Black Hole; exactly four in a row as Pulsar; three in a row as a basic clear. A tile claimed by a higher-priority pattern SHALL NOT count toward any lower-priority pattern, so no tile belongs to two matches.

#### Scenario: Five in a row
- GIVEN five red planets in a row
- WHEN matches are detected
- THEN one Supernova match is reported
- AND no four-in-a-row or three-in-a-row is reported for the same tiles

#### Scenario: T shape
- GIVEN a horizontal run of three and a vertical run of three sharing one tile
- WHEN matches are detected
- THEN one Black Hole match of five tiles is reported

### Requirement: Larger matches create special tiles

When a Pulsar, Black Hole or Supernova pattern is cleared, the system SHALL leave a special tile of that kind on the board at a cell within the cleared pattern. A special tile SHALL look distinct from ordinary tiles and SHALL keep the colour of the tiles that created it.

#### Scenario: Four in a row creates a Pulsar
- GIVEN a swap that lines up exactly four blue planets
- WHEN the match resolves
- THEN three of the tiles clear
- AND a blue Pulsar tile remains in their place

### Requirement: Special tiles have their own effects

When a special tile is cleared as part of a match, the system SHALL apply its effect in addition to the match: a Pulsar SHALL clear its entire row; a Black Hole SHALL clear the 3 by 3 area centred on it; a Supernova SHALL clear every tile of one type on the board. Tiles cleared by an effect SHALL score as cleared tiles and SHALL trigger the usual fall, refill and cascade.

#### Scenario: Matching a Pulsar
- GIVEN a Pulsar in row 4
- WHEN it is part of a three-tile match
- THEN every tile in row 4 is cleared
- AND the board falls and refills as usual
