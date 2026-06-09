import 'package:flutter/material.dart';

import '../game/match3_game.dart';
import '../game/theme/cosmic_theme.dart';
import '../services/feedback_launcher.dart';
import '../services/feedback_service.dart';
import 'stat_card.dart';

const _kCardFill = Color(0x0FFFFFFF);   // 6% white fill
const _kCardBorder = Color(0x1AFFFFFF); // 10% white border

class HudOverlay extends StatelessWidget {
  final Match3Game game;
  final FeedbackService? feedbackService;
  final GlobalKey? screenshotKey;

  const HudOverlay({
    required this.game,
    this.feedbackService,
    this.screenshotKey,
    super.key,
  });

  Future<void> _onFeedbackTap(BuildContext context) async {
    final service = feedbackService;
    if (service == null || screenshotKey == null) return;
    await launchFeedback(
      context: context,
      service: service,
      screenshotKey: screenshotKey!,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: game.scoreNotifier,
      builder: (context, scores, _) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: Row(
            children: [
              Expanded(flex: 2,
                  child: StatCard(label: 'SCORE',
                      value: scores.score.toString(),
                      accentColor: kCosmicAccent)),
              const SizedBox(width: 8),
              Expanded(
                  child: StatCard(label: 'BEST',
                      value: scores.best.toString(),
                      accentColor: kCosmicAccent)),
              if (feedbackService != null) ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 42,
                  height: 42,
                  child: IconButton(
                    onPressed: () => _onFeedbackTap(context),
                    icon: const Icon(Icons.feedback_outlined, size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: _kCardFill,
                      side: const BorderSide(color: _kCardBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    color: kCosmicAccent,
                    tooltip: 'Send Feedback',
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

