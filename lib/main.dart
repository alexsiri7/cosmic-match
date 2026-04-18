import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'core/logger.dart';
import 'game/match3_game.dart';
import 'game/theme/app_theme.dart';
import 'screens/game_screen.dart';
import 'screens/home_screen.dart';
import 'screens/map_screen.dart';
import 'services/key_service.dart';
import 'services/progress_service.dart';

enum _Screen { home, game, map }

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Silence Flutter framework's own debugPrint in release — gameLogger handles game-level logs.
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  await Hive.initFlutter();
  final cipher = await KeyService().getCipher();
  final progressService = ProgressService(cipher: cipher);

  gameLogger.i('CosmicMatch initialised — hive ready, progressService ready');

  void launch() => runApp(ProviderScope(child: CosmicMatchApp(progressService: progressService)));

  const sentryDsn = String.fromEnvironment('SENTRY_DSN', defaultValue: '');
  if (sentryDsn.isEmpty) {
    debugPrint('Sentry disabled: SENTRY_DSN not set at compile time.');
    launch();
    return;
  }

  try {
    final packageInfo = await PackageInfo.fromPlatform();
    await SentryFlutter.init(
      (options) {
        options.dsn = sentryDsn;
        options.environment = kReleaseMode ? 'release' : 'debug';
        options.release =
            '${packageInfo.packageName}@${packageInfo.version}+${packageInfo.buildNumber}';
        // V1 privacy defaults: no performance tracing, no PII, no screenshots.
        // Revisit tracesSampleRate when the app has a backend (post-V1).
        options.tracesSampleRate = 0.0;
        options.sendDefaultPii = false;
        options.attachScreenshot = false;
      },
      appRunner: launch,
    );
  } catch (e, stack) {
    // Sentry init failure must not prevent the app from launching.
    gameLogger.w('Sentry init failed — crash reporting disabled', error: e, stackTrace: stack);
    launch();
  }
}

class CosmicMatchApp extends StatefulWidget {
  final ProgressService progressService;

  const CosmicMatchApp({super.key, required this.progressService});

  @override
  State<CosmicMatchApp> createState() => _CosmicMatchAppState();
}

class _CosmicMatchAppState extends State<CosmicMatchApp> {
  late final Match3Game _game;
  _Screen _screen = _Screen.home;

  @override
  void initState() {
    super.initState();
    _game = Match3Game(progressService: widget.progressService);
  }

  Widget _buildScreen() {
    return switch (_screen) {
      _Screen.home => HomeScreen(
          onPlay: () => setState(() => _screen = _Screen.game),
          onMap: () => setState(() => _screen = _Screen.map),
        ),
      _Screen.game => GameScreen(
          game: _game,
          onBack: () => setState(() => _screen = _Screen.home),
        ),
      _Screen.map => MapScreen(
          onBack: () => setState(() => _screen = _Screen.home),
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cosmic Match',
      theme: cosmicTheme(),
      home: _buildScreen(),
    );
  }
}
