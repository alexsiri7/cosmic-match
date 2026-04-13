import 'package:flutter/foundation.dart';

/// Manages game state (score) as a ChangeNotifier.
/// Shared between Flame game components and Flutter overlay widgets.
class GameState extends ChangeNotifier {
  int _score = 0;
  int _displayedScore = 0;

  int get score => _score;
  int get displayedScore => _displayedScore;

  void addScore(int points) {
    _score += points;
    notifyListeners();
  }

  /// Called by the HUD animation to update the displayed (animated) score.
  void updateDisplayedScore(int value) {
    _displayedScore = value;
    notifyListeners();
  }

  void reset() {
    _score = 0;
    _displayedScore = 0;
    notifyListeners();
  }
}
