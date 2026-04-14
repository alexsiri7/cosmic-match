import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'game/match3_game.dart';
import 'services/key_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  // SEC-004: fetch or generate AES-256 key from Android Keystore.
  // Returns null on platforms / emulators without secure storage.
  // ignore: unused_local_variable
  final cipher = await KeyService().getCipher();
  // SEC-004: cipher ready for ProgressService injection in M2 game wiring
  runApp(
    const ProviderScope(
      child: CosmicMatchApp(),
    ),
  );
}

class CosmicMatchApp extends StatelessWidget {
  const CosmicMatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cosmic Match',
      theme: ThemeData.dark(),
      home: GameWidget(game: Match3Game()),
    );
  }
}
