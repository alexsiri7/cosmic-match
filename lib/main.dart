import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'core/constants.dart';
import 'core/logger.dart';
import 'game/match3_game.dart';
import 'screens/feedback_sheet.dart';
import 'screens/game_screen.dart';
import 'screens/home_screen.dart';
import 'services/feedback_service.dart';
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
  final cipher = await KeyService().getCipher();
  final progressService = ProgressService(cipher: cipher);

  gameLogger.i('CosmicMatch initialised — hive ready, progressService ready');

  const feedbackWorkerUrl = String.fromEnvironment(
    'FEEDBACK_WORKER_URL',
    defaultValue: 'https://feedback.alexsiri7.workers.dev/',
  );
  final feedbackService = FeedbackService(workerUrl: feedbackWorkerUrl);
  feedbackService.listenConnectivity();

  void launch() => runApp(ProviderScope(
    child: CosmicMatchApp(
      progressService: progressService,
      feedbackService: feedbackService,
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

  /// Overrides the [Match3Game] instance used by the app.
  /// For testing only — bypasses Hive-backed [ProgressService] initialisation.
  @visibleForTesting
  final Match3Game? gameOverride;

  const CosmicMatchApp({
    super.key,
    required this.progressService,
    this.feedbackService,
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

  Future<Uint8List> _captureScreenshot() async {
    final context = _repaintBoundaryKey.currentContext;
    if (context == null) {
      gameLogger.w('_captureScreenshot: repaint boundary context is null');
      throw StateError('RepaintBoundary not yet mounted');
    }
    final boundary = context.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2.0);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) {
      gameLogger.w('_captureScreenshot: toByteData returned null');
      throw StateError('Failed to encode screenshot to PNG');
    }
    return data.buffer.asUint8List();
  }

  Future<void> _showFeedback() async {
    final service = widget.feedbackService;
    if (service == null) return;
    Uint8List screenshotBytes;
    try {
      screenshotBytes = await _captureScreenshot();
    } catch (e) {
      gameLogger.w('_showFeedback: screenshot capture failed', error: e);
      // Fall back to 1×1 transparent PNG so FeedbackSheet still opens.
      screenshotBytes = kTransparentPng;
    }
    if (!mounted) return;
    final navContext = _navigatorKey.currentContext;
    // navContext is null when _showFeedback is called before the MaterialApp's
    // Navigator has mounted (e.g. during app startup). The .mounted check is an
    // extra defensive guard; GlobalKey.currentContext is non-null only while the
    // widget is in the tree, so it is effectively always true when non-null.
    if (navContext == null || !navContext.mounted) {
      gameLogger.w('_showFeedback: navigator context unavailable');
      return;
    }
    showFeedbackSheet(
      navContext,
      screenshotBytes: screenshotBytes,
      onSubmit: ({
        required String type,
        required String message,
        required String screenshotB64,
      }) async {
        final packageInfo = await PackageInfo.fromPlatform();
        await service.submit(
          type: type,
          message: message,
          screenshotB64: screenshotB64,
          appVersion: '${packageInfo.version}+${packageInfo.buildNumber}',
          os: Platform.operatingSystem,
          device: Platform.operatingSystemVersion,
        );
      },
    );
  }

  Widget _buildScreen() {
    switch (_currentScreen) {
      case _Screen.home:
        return HomeScreen(
          onPlay: () => setState(() => _currentScreen = _Screen.game),
          onMap: () {}, // Map not yet implemented
          onFeedback: _showFeedback,
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
