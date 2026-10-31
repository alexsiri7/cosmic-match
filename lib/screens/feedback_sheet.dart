import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants.dart';
import '../core/logger.dart';
import '../game/theme/cosmic_theme.dart';
import '../models/feedback_result.dart';

/// Shows the feedback bottom sheet. When the user taps Submit, [onSubmit] is
/// called with the selected type, description, and annotated screenshot.
/// When the report was sent or queued for later, the sheet is dismissed and a
/// SnackBar says which (with an action to copy the issue link when the filed
/// issue's number is known). When it was rate-limited, not sent, or the
/// submit failed, the sheet stays open with the description kept and says why
/// above the Submit button (in a SnackBar instead if the player dismissed the
/// sheet while waiting); a rate-limited or not-sent result also refreshes the
/// cooldown.
Future<void> showFeedbackSheet(
  BuildContext context, {
  required Uint8List screenshotBytes,
  required Future<FeedbackResult> Function({
    required String type,
    required String message,
    required String screenshotB64,
  }) onSubmit,
  Future<int> Function()? checkCooldown,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _FeedbackSheet(
      screenshotBytes: screenshotBytes,
      onSubmit: onSubmit,
      checkCooldown: checkCooldown,
    ),
  );
}

class _FeedbackSheet extends StatefulWidget {
  final Uint8List screenshotBytes;
  final Future<FeedbackResult> Function({
    required String type,
    required String message,
    required String screenshotB64,
  }) onSubmit;
  final Future<int> Function()? checkCooldown;

  const _FeedbackSheet({
    required this.screenshotBytes,
    required this.onSubmit,
    this.checkCooldown,
  });

  @override
  State<_FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<_FeedbackSheet> {
  final _descController = TextEditingController();
  String _selectedType = 'bug';
  final List<List<Offset?>> _drawPaths = [[]];
  bool _submitting = false;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;
  bool _drawMode = true;
  bool _privacyAccepted = false;
  bool _policyLinkCopied = false;
  String? _submitError;
  Offset _imageOffset = Offset.zero;
  // Updated by LayoutBuilder on each build; read by `_renderAnnotatedScreenshot()`
  // to scale annotation coordinates from preview space to image space.
  double _previewWidth = 300;
  double _previewHeight = 200;

  @override
  void initState() {
    super.initState();
    _initCooldown();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _initCooldown() async {
    final fn = widget.checkCooldown;
    if (fn == null) return;
    final secs = await fn();
    if (!mounted) return;
    if (secs > 0) {
      setState(() => _cooldownSeconds = secs);
      _startCooldownTimer();
    }
  }

  void _startCooldownTimer() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        _cooldownTimer?.cancel();
        return;
      }
      setState(() {
        if (_cooldownSeconds > 0) _cooldownSeconds--;
      });
      if (_cooldownSeconds == 0) _cooldownTimer?.cancel();
    });
  }

  bool get _canSubmit =>
      _descController.text.trim().length >= kMinFeedbackMessageLength &&
      !_submitting &&
      _cooldownSeconds == 0 &&
      _privacyAccepted;

  Future<void> _handleSubmit() async {
    if (!_canSubmit) return;
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    // Captured before the sheet pops so the confirmation lands on the page
    // underneath rather than on the dismissed sheet. Outcomes that keep the
    // sheet open are shown in the sheet itself, since the modal route covers
    // the page's SnackBars — unless the player has already dismissed it.
    final messenger = ScaffoldMessenger.of(context);

    try {
      final annotatedB64 = await _renderAnnotatedScreenshot();
      if (!mounted) return;
      final result = await widget.onSubmit(
        type: _selectedType,
        message: _descController.text.trim(),
        screenshotB64: annotatedB64,
      );
      String withScreenshotNote(String text) => annotatedB64.isEmpty
          ? "$text The screenshot couldn't be attached."
          : text;
      switch (result.outcome) {
        case FeedbackOutcome.sent:
          if (mounted) Navigator.pop(context);
          final issueNumber = result.issueNumber;
          if (issueNumber != null) {
            _showIssueReference(
              messenger,
              issueNumber,
              withScreenshotNote('Feedback sent as issue #$issueNumber.'),
            );
          } else {
            _showMessage(messenger, withScreenshotNote('Feedback sent.'));
          }
        case FeedbackOutcome.queued:
          if (mounted) Navigator.pop(context);
          _showMessage(
            messenger,
            withScreenshotNote(
              "Couldn't reach the server — your feedback will be sent "
              'automatically later.',
            ),
          );
        case FeedbackOutcome.rateLimited:
          _showSubmitError(
            messenger,
            'Too many reports — please wait before sending again.',
          );
          await _initCooldown();
        case FeedbackOutcome.notSent:
          _showSubmitError(messenger, "Feedback couldn't be sent.");
          await _initCooldown();
      }
    } catch (e, stack) {
      gameLogger.e('FeedbackSheet: submit failed', error: e, stackTrace: stack);
      _showSubmitError(messenger, 'Failed to send feedback.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showSubmitError(ScaffoldMessengerState messenger, String text) {
    if (mounted) {
      setState(() => _submitError = text);
    } else {
      _showMessage(messenger, text);
    }
  }

  void _showMessage(ScaffoldMessengerState messenger, String text) {
    messenger.showSnackBar(SnackBar(content: Text(text)));
  }

  void _showIssueReference(
    ScaffoldMessengerState messenger,
    int issueNumber,
    String text,
  ) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(text),
        duration: const Duration(seconds: 10),
        action: SnackBarAction(
          label: 'COPY LINK',
          onPressed: () => Clipboard.setData(ClipboardData(
            text: 'https://github.com/$kFeedbackIssuesRepo/issues/$issueNumber',
          )),
        ),
      ),
    );
  }

  Future<String> _renderAnnotatedScreenshot() async {
    final codec = await ui.instantiateImageCodec(widget.screenshotBytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImage(image, Offset.zero, Paint());

    // Draw annotations scaled from preview space to image space
    final paint = _strokeAnnotationPaint();
    final scaleX = image.width.toDouble() / _previewWidth;
    final scaleY = image.height.toDouble() / _previewHeight;
    for (final path in _drawPaths) {
      for (int i = 0; i < path.length - 1; i++) {
        final a = path[i];
        final b = path[i + 1];
        if (a == null || b == null) continue;
        canvas.drawLine(
          Offset((a.dx - _imageOffset.dx) * scaleX, (a.dy - _imageOffset.dy) * scaleY),
          Offset((b.dx - _imageOffset.dx) * scaleX, (b.dy - _imageOffset.dy) * scaleY),
          paint,
        );
      }
    }

    final picture = recorder.endRecording();
    final rendered = await picture.toImage(image.width, image.height);
    final byteData = await rendered.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    rendered.dispose();

    if (byteData == null) return '';
    final encoded = base64Encode(byteData.buffer.asUint8List());
    if (encoded.length > kMaxScreenshotB64Bytes) {
      gameLogger.w(
        '_renderAnnotatedScreenshot: screenshot exceeds ${kMaxScreenshotB64Bytes}B '
        '(actual=${encoded.length}) — omitting screenshot',
      );
      return '';
    }
    return encoded;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0.0, -1.0),
          radius: 1.2,
          colors: [kCosmicNebulaA.withValues(alpha: 0.6), kCosmicInk],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'SEND FEEDBACK',
                  style: GoogleFonts.ibmPlexMono(
                    fontSize: 11,
                    letterSpacing: 2.5,
                    color: Colors.white.withValues(alpha: 0.65),
                  ),
                ),
                const SizedBox(height: 16),
                // Screenshot preview with draw overlay
                LayoutBuilder(
                  builder: (context, constraints) {
                    _previewWidth = constraints.maxWidth;
                    _previewHeight = _previewWidth * 0.6;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: Icon(
                            _drawMode ? Icons.edit : Icons.pan_tool,
                            color: _drawMode
                                ? kCosmicAccent
                                : Colors.white.withValues(alpha: 0.6),
                            size: 18,
                          ),
                          tooltip: _drawMode ? 'Switch to pan mode' : 'Switch to draw mode',
                          onPressed: () => setState(() => _drawMode = !_drawMode),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: _previewWidth,
                            height: _previewHeight,
                            child: GestureDetector(
                              onPanStart: (d) {
                                if (_drawMode) {
                                  setState(() {
                                    _drawPaths.add([d.localPosition]);
                                  });
                                }
                              },
                              onPanUpdate: (d) {
                                setState(() {
                                  if (_drawMode) {
                                    _drawPaths.last.add(d.localPosition);
                                  } else {
                                    _imageOffset += d.delta;
                                  }
                                });
                              },
                              onPanEnd: (_) {
                                if (_drawMode) _drawPaths.last.add(null);
                              },
                              child: CustomPaint(
                                foregroundPainter: _DrawPainter(_drawPaths),
                                child: Transform.translate(
                                  offset: _imageOffset,
                                  child: Image.memory(
                                    widget.screenshotBytes,
                                    fit: BoxFit.cover,
                                    width: _previewWidth,
                                    height: _previewHeight,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                // Type picker
                Row(
                  children: [
                    for (final (i, (label, type)) in [
                      ('Bug', 'bug'),
                      ('Feature', 'feature'),
                      ('Other', 'other'),
                    ].indexed) ...[
                      if (i > 0) const SizedBox(width: 8),
                      _TypeButton(
                        label: label,
                        selected: _selectedType == type,
                        onTap: () => setState(() => _selectedType = type),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                // Description field
                TextField(
                  controller: _descController,
                  maxLines: 3,
                  maxLength: kMaxFeedbackMessageLength,
                  style: GoogleFonts.ibmPlexMono(fontSize: 13, color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Describe the issue...',
                    hintStyle: GoogleFonts.ibmPlexMono(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                    helperText: 'At least $kMinFeedbackMessageLength characters',
                    helperStyle: GoogleFonts.ibmPlexMono(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.06),
                    border: _unfocusedBorder,
                    enabledBorder: _unfocusedBorder,
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: kCosmicAccent.withValues(alpha: 0.5)),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 20),
                // Privacy consent
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: _privacyAccepted,
                        activeColor: kCosmicAccent,
                        checkColor: kCosmicInk,
                        onChanged: (value) =>
                            setState(() => _privacyAccepted = value!),
                      ),
                      Flexible(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            'Your feedback type, description, annotated screenshot, '
                            'app version, OS, and device model will be sent to our '
                            'server and filed as an issue on the public GitHub '
                            'repository github.com/$kFeedbackIssuesRepo, where it '
                            'stays until deleted. Do not include personal information. '
                            'If it cannot be sent right away it is kept on this device '
                            'for up to $kFeedbackQueueTtlDays days.',
                            style: GoogleFonts.ibmPlexMono(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.55),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Privacy policy: $kPrivacyPolicyUrl',
                          style: GoogleFonts.ibmPlexMono(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.55),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          _policyLinkCopied ? Icons.check : Icons.copy,
                          color: Colors.white.withValues(alpha: 0.6),
                          size: 18,
                        ),
                        tooltip: 'Copy privacy policy link',
                        onPressed: () async {
                          await Clipboard.setData(
                            const ClipboardData(text: kPrivacyPolicyUrl),
                          );
                          if (mounted) setState(() => _policyLinkCopied = true);
                        },
                      ),
                    ],
                  ),
                ),
                if (_submitError case final error?)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Center(
                      child: Text(
                        error,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.ibmPlexMono(
                          fontSize: 12,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                  ),
                // Cooldown countdown
                if (_cooldownSeconds > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Center(
                      child: Text(
                        'Try again in $_cooldownSeconds seconds',
                        style: GoogleFonts.ibmPlexMono(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                // Submit button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _canSubmit ? _handleSubmit : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kCosmicAccent,
                      foregroundColor: kCosmicInk,
                      disabledBackgroundColor: kCosmicAccent.withValues(alpha: 0.3),
                      disabledForegroundColor: kCosmicInk.withValues(alpha: 0.5),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: kCosmicInk),
                          )
                        : const Text('Submit'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TypeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? kCosmicAccent.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.06),
            border: Border.all(
              color: selected ? kCosmicAccent : Colors.white.withValues(alpha: 0.1),
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.ibmPlexMono(
              fontSize: 12,
              letterSpacing: 1,
              color: selected ? kCosmicAccent : Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }
}

final _unfocusedBorder = OutlineInputBorder(
  borderRadius: BorderRadius.circular(12),
  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
);

Paint _strokeAnnotationPaint() => Paint()
  ..color = Colors.red
  ..strokeWidth = 3.0
  ..strokeCap = StrokeCap.round
  ..style = PaintingStyle.stroke;

class _DrawPainter extends CustomPainter {
  final List<List<Offset?>> paths;
  _DrawPainter(this.paths);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = _strokeAnnotationPaint();
    for (final path in paths) {
      for (int i = 0; i < path.length - 1; i++) {
        final a = path[i];
        final b = path[i + 1];
        if (a == null || b == null) continue;
        canvas.drawLine(a, b, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DrawPainter oldDelegate) => paths != oldDelegate.paths;
}
