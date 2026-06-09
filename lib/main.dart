import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'core/constants.dart';
import 'core/logger.dart';
import 'core/sentry_filters.dart';
import 'game/match3_game.dart';
import 'screens/game_screen.dart';
import 'screens/home_screen.dart';
import 'services/feedback_launcher.dart';
import 'services/feedback_queue_service.dart';
import 'services/feedback_service.dart';
import 'services/rate_limit_service.dart';
import 'services/in_app_update_service.dart';
import 'services/key_service.dart';
import 'services/progress_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Silence Flutter framework's own debugPrint in release — gameLogger handles game-level logs.
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  await Hive.initFlutter();
  final keyService = KeyService();
  final cipher = await keyService.getCipher();
  final hmacKey = await keyService.getHmacKey();
  final progressService = ProgressService(cipher: cipher, hmacKey: hmacKey);
  final queueService = FeedbackQueueService(cipher: cipher, hmacKey: hmacKey);
  await queueService.expireOldItems(kFeedbackQueueTtlDays);

  gameLogger.i('CosmicMatch initialised — hive ready, progressService ready');

  const feedbackWorkerUrl = String.fromEnvironment(
    'FEEDBACK_WORKER_URL',
    defaultValue: 'https://feedback.alexsiri7.workers.dev/',
  );
  const feedbackHmacSecret = String.fromEnvironment('FEEDBACK_HMAC_SECRET', defaultValue: '');
  final rateLimitService = RateLimitService();
  final feedbackService = FeedbackService(
    workerUrl: feedbackWorkerUrl,
    workerHmacSecret: feedbackHmacSecret,
    rateLimitService: rateLimitService,
    cipher: cipher,
    hmacKey: hmacKey,
  );
  feedbackService.listenConnectivity();

  void launch() => runApp(ProviderScope(
    child: CosmicMatchApp(
      progressService: progressService,
      feedbackService: feedbackService,
      queueService: queueService,
    ),
  ));

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
        options.beforeSend = dropUnactionableEvents;
      },
      appRunner: launch,
    );
  } catch (e, stack) {
    // Sentry init failure must not prevent the app from launching.
    gameLogger.w('Sentry init failed — crash reporting disabled', error: e, stackTrace: stack);
    launch();
  }
}

enum _Screen { home, game }

class CosmicMatchApp extends StatefulWidget {
  final ProgressService progressService;
  final FeedbackService? feedbackService;
  final FeedbackQueueService? queueService;

  /// Overrides the [Match3Game] instance used by the app.
  /// For testing only — bypasses Hive-backed [ProgressService] initialisation.
  @visibleForTesting
  final Match3Game? gameOverride;

  const CosmicMatchApp({
    super.key,
    required this.progressService,
    this.feedbackService,
    this.queueService,
    this.gameOverride,
  });

  @override
  State<CosmicMatchApp> createState() => _CosmicMatchAppState();
}

class _CosmicMatchAppState extends State<CosmicMatchApp> {
  _Screen _currentScreen = _Screen.home;
  late final Match3Game _game;
  final _repaintBoundaryKey = GlobalKey();
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  final _updateService = InAppUpdateService();

  @override
  void initState() {
    super.initState();
    _game = widget.gameOverride ?? Match3Game(progressService: widget.progressService);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateService.checkAndStartFlexibleUpdate(
        onUpdateDownloaded: _onUpdateDownloaded,
      );
    });
  }

  void _onUpdateDownloaded() {
    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: const Text('Update ready'),
        duration: const Duration(days: 1),
        action: SnackBarAction(
          label: 'Restart',
          onPressed: () => _updateService.completeFlexibleUpdate(),
        ),
      ),
    );
  }

  Future<void> _showFeedback() async {
    final service = widget.feedbackService;
    if (service == null) return;
    if (!mounted) return;
    final navContext = _navigatorKey.currentContext;
    if (navContext == null || !navContext.mounted) {
      gameLogger.w('_showFeedback: navigator context unavailable');
      return;
    }
    await launchFeedback(
      context: navContext,
      service: service,
      screenshotKey: _repaintBoundaryKey,
    );
  }

  Future<void> _clearFeedbackQueue() async {
    final ok = await widget.queueService?.clearAll() ?? false;
    if (!mounted) return;
    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(ok ? 'Feedback queue cleared' : 'Could not clear queue'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildScreen() {
    switch (_currentScreen) {
      case _Screen.home:
        return HomeScreen(
          onPlay: () => setState(() => _currentScreen = _Screen.game),
          onMap: () {}, // Map not yet implemented
          onFeedback: _showFeedback,
          onClearFeedbackQueue: _clearFeedbackQueue,
        );
      case _Screen.game:
        return GameScreen(
          game: _game,
          onBack: () => setState(() => _currentScreen = _Screen.home),
          onFeedback: _showFeedback,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _scaffoldMessengerKey,
      title: 'Cosmic Match',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D0A1A),
      ),
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: RepaintBoundary(
            key: _repaintBoundaryKey,
            child: _buildScreen(),
          ),
        ),
      ),
    );
  }
}
