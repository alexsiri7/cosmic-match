import '../core/logger.dart';

class CascadeController {
  /// Maximum cascade chain depth before aborting.
  /// Set to 20 as a practical upper bound for an 8×8 grid;
  /// real games rarely exceed 10 cascades. Prevents runaway loops
  /// from bugs in gravity/refill logic.
  static const int maxDepth = 20;
  int _depth = 0;

  int get depth => _depth;

  bool get canContinue => _depth < maxDepth;

  void increment() {
    if (_depth >= maxDepth) {
      // Cap rather than overflow; caller must check canContinue before proceeding
      gameLogger.w('CascadeController: maxDepth ($maxDepth) reached, aborting cascade');
      return;
    }
    _depth++;
  }

  void reset() => _depth = 0;
}
