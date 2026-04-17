import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'game/match3_game.dart';
import 'services/key_service.dart';
import 'services/progress_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  final cipher = await KeyService().getCipher();
  final progressService = ProgressService(cipher: cipher);
  runApp(
    ProviderScope(
      child: CosmicMatchApp(progressService: progressService),
    ),
  );
}

class CosmicMatchApp extends StatefulWidget {
  final ProgressService progressService;

  const CosmicMatchApp({super.key, required this.progressService});

  @override
  State<CosmicMatchApp> createState() => _CosmicMatchAppState();
}

class _CosmicMatchAppState extends State<CosmicMatchApp> {
  final _gameKey = GlobalKey<RiverpodAwareGameWidgetState<Match3Game>>();
  late final Match3Game _game;

  @override
  void initState() {
    super.initState();
    _game = Match3Game(progressService: widget.progressService);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cosmic Match',
      theme: ThemeData.dark(),
      home: SafeArea(
        child: RiverpodAwareGameWidget(
          key: _gameKey,
          game: _game,
        ),
      ),
    );
  }
}
