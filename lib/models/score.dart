class Score {
  static const int _max = 999999999;
  int _value = 0;

  int get value => _value;

  void add(int points) {
    assert(points >= 0, 'Points must be non-negative');
    if (points <= 0) return; // release-mode guard; negative inputs are ignored
    _value = (_value + points).clamp(0, _max);
  }

  void reset() => _value = 0;
}
