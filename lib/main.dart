import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'game/match3_game.dart';
import 'services/key_service.dart';
import 'services/progress_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  final cipher = await KeyService().getCipher();
  final progressService = ProgressService(cipher: cipher);

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
  } catch (_) {
    // Sentry init failure must not prevent the app from launching.
    launch();
  }
}

class CosmicMatchApp extends StatefulWidget {
  final ProgressService progressService;
  final Match3Game? game; // @visibleForTesting — integration tests pass pre-built game

  const CosmicMatchApp({super.key, required this.progressService, this.game});

  @override
  State<CosmicMatchApp> createState() => _CosmicMatchAppState();
}

class _CosmicMatchAppState extends State<CosmicMatchApp> {
  final _gameKey = GlobalKey<RiverpodAwareGameWidgetState<Match3Game>>();
  late final Match3Game _game;

  @override
  void initState() {
    super.initState();
    _game = widget.game ?? Match3Game(progressService: widget.progressService);
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
