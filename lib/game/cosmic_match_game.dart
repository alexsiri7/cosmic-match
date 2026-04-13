import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../models/board_state.dart';
import 'components/board_component.dart';

class CosmicMatchGame extends FlameGame {
  late final BoardState boardState;
  late final BoardComponent boardComponent;

  @override
  Color backgroundColor() => const Color(0xFF0A0E21);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    boardState = BoardState();
    boardState.randomFill();

    boardComponent = BoardComponent(boardState: boardState);
    add(boardComponent);
  }
}
