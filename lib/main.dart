import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'game/match3_game.dart';
import 'services/key_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  // SEC-004: trigger first-launch key generation — generates and stores the
  // AES-256 key in platform secure storage if not already present.
  // Returns null on platforms / emulators without secure storage (graceful degradation).
  // TODO(M2): capture cipher and pass to ProgressService via Riverpod provider.
  await KeyService().getCipher();
  runApp(
    const ProviderScope(
      child: CosmicMatchApp(),
    ),
  );
}

class CosmicMatchApp extends StatefulWidget {
  const CosmicMatchApp({super.key});

  @override
  State<CosmicMatchApp> createState() => _CosmicMatchAppState();
}

class _CosmicMatchAppState extends State<CosmicMatchApp> {
  final _gameKey = GlobalKey<RiverpodAwareGameWidgetState<Match3Game>>();
  final _game = Match3Game();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cosmic Match',
      theme: ThemeData.dark(),
      home: RiverpodAwareGameWidget(
        key: _gameKey,
        game: _game,
      ),
    );
  }
}
