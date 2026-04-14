class Score {
  static const int _max = 999999999;
  int _value = 0;

  int get value => _value;

  void add(int points) {
    if (points <= 0) return; // negative inputs are ignored
    _value = (_value + points).clamp(0, _max);
  }

  void reset() => _value = 0;
}
