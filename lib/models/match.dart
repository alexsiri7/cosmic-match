/// Represents a match of 3+ tiles on the board.
class Match {
  /// The positions (row, col) of matched tiles.
  final List<(int, int)> positions;

  /// The size of the match (number of tiles).
  int get size => positions.length;

  Match(this.positions);

  @override
  String toString() => 'Match(size: $size, positions: $positions)';
}
