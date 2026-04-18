import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:workmanager/workmanager.dart' as wm;
import 'core/logger.dart';
import 'game/match3_game.dart';
import 'screens/game_screen.dart';
import 'screens/home_screen.dart';
import 'services/feedback_queue_service.dart';
import 'services/github_feedback_client.dart';
import 'services/key_service.dart';
import 'services/progress_service.dart';
import 'widgets/feedback_modal.dart';

/// WorkManager background-task entry point.
///
/// Runs in a **separate Dart isolate** spun up by the OS scheduler, so all
/// Flutter/Hive state must be re-initialised here. [KeyService.getCipher] is
/// called to match the cipher used in the foreground app — the box must be
/// opened with the same cipher or Hive will reject it.
@pragma('vm:entry-point')
void callbackDispatcher() {
  wm.Workmanager().executeTask((task, inputData) async {
    if (task == 'feedbackRetry') {
      await Hive.initFlutter();
      final cipher = await KeyService().getCipher();
      final queue = FeedbackQueueService(cipher: cipher);
      final client = GitHubFeedbackClient();
      final items = await queue.loadQueue();
      for (final item in items) {
        if (item.uploaded) continue;
        try {
          final pngBytes = base64Decode(item.screenshotBase64);
          final imageUrl = await client.uploadImage(item.id, pngBytes);
          final issueUrl =
              await client.createIssue(item.description, imageUrl);
          await queue.markUploaded(item.id, issueUrl);
        } catch (e, stack) {
          gameLogger.w('feedbackRetry: failed for ${item.id}', error: e, stackTrace: stack);
        }
      }
    }
    return true;
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Silence Flutter framework's own debugPrint in release — gameLogger handles game-level logs.
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  await Hive.initFlutter();
  final cipher = await KeyService().getCipher();
  final progressService = ProgressService(cipher: cipher);
  final feedbackQueue = FeedbackQueueService(cipher: cipher);
  final feedbackClient = GitHubFeedbackClient();

  // isInDebugMode deprecated in workmanager 0.9.x but not yet removed.
  // Remove this argument once workmanager drops the parameter.
  await wm.Workmanager().initialize(callbackDispatcher, isInDebugMode: !kReleaseMode); // ignore: deprecated_member_use

  gameLogger.i('CosmicMatch initialised — hive ready, progressService ready');

  void launch() => runApp(ProviderScope(
      child: CosmicMatchApp(
        progressService: progressService,
        feedbackQueue: feedbackQueue,
        feedbackClient: feedbackClient,
      )));

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
  final FeedbackQueueService feedbackQueue;
  final GitHubFeedbackClient feedbackClient;

  const CosmicMatchApp({
    super.key,
    required this.progressService,
    required this.feedbackQueue,
    required this.feedbackClient,
  });

  @override
  State<CosmicMatchApp> createState() => _CosmicMatchAppState();
}

class _CosmicMatchAppState extends State<CosmicMatchApp> {
  _Screen _currentScreen = _Screen.home;
  late final Match3Game _game;
  final _repaintBoundaryKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _game = Match3Game(progressService: widget.progressService);
    _scheduleRetryIfNeeded();
  }

  Future<void> _scheduleRetryIfNeeded() async {
    final items = await widget.feedbackQueue.loadQueue();
    if (items.any((i) => !i.uploaded)) {
      try {
        await wm.Workmanager().registerOneOffTask(
          'feedbackRetry',
          'feedbackRetry',
          constraints: wm.Constraints(networkType: wm.NetworkType.connected),
        );
      } catch (e, stack) {
        gameLogger.w('_scheduleRetryIfNeeded: WorkManager registration failed', error: e, stackTrace: stack);
      }
    }
  }

  Future<Uint8List> _captureScreenshot() async {
    final context = _repaintBoundaryKey.currentContext;
    if (context == null) {
      gameLogger.w('_captureScreenshot: repaint boundary context is null');
      throw StateError('RepaintBoundary not yet mounted');
    }
    final boundary = context.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2.0);
    final data = await image.toByteData(format: ImageByteFormat.png);
    if (data == null) {
      gameLogger.w('_captureScreenshot: toByteData returned null');
      throw StateError('Failed to encode screenshot to PNG');
    }
    return data.buffer.asUint8List();
  }

  Future<void> _showFeedback() async {
    try {
      final screenshot = await _captureScreenshot();
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => FeedbackModal(
          screenshot: screenshot,
          queue: widget.feedbackQueue,
          client: widget.feedbackClient,
        ),
      );
    } catch (e) {
      gameLogger.w('_showFeedback: screenshot capture failed', error: e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not capture screenshot')),
      );
    }
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
      title: 'Cosmic Match',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D0A1A),
      ),
      home: SafeArea(
        child: RepaintBoundary(
          key: _repaintBoundaryKey,
          child: _buildScreen(),
        ),
      ),
    );
  }
}
