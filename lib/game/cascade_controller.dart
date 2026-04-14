class CascadeController {
  static const int maxDepth = 20;
  int _depth = 0;

  int get depth => _depth;

  bool get canContinue => _depth < maxDepth;

  void increment() {
    assert(canContinue, 'Cascade depth exceeded');
    _depth++;
  }

  void reset() => _depth = 0;
}
