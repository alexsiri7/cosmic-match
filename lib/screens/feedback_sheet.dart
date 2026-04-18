import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/logger.dart';
import '../game/theme/app_theme.dart';

/// Shows the feedback bottom sheet. When the user taps Submit, [onSubmit] is
/// called with the selected type, description, and annotated screenshot.
/// On success the sheet is dismissed; on failure a SnackBar is shown.
Future<void> showFeedbackSheet(
  BuildContext context, {
  required Uint8List screenshotBytes,
  required Future<void> Function({
    required String type,
    required String message,
    required String screenshotB64,
  }) onSubmit,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _FeedbackSheet(
      screenshotBytes: screenshotBytes,
      onSubmit: onSubmit,
    ),
  );
}

class _FeedbackSheet extends StatefulWidget {
  final Uint8List screenshotBytes;
  final Future<void> Function({
    required String type,
    required String message,
    required String screenshotB64,
  }) onSubmit;

  const _FeedbackSheet({
    required this.screenshotBytes,
    required this.onSubmit,
  });

  @override
  State<_FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<_FeedbackSheet> {
  final _descController = TextEditingController();
  String _selectedType = 'bug';
  final List<List<Offset?>> _drawPaths = [[]];
  bool _submitting = false;

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  bool get _canSubmit => _descController.text.trim().isNotEmpty && !_submitting;

  Future<void> _handleSubmit() async {
    if (!_canSubmit) return;
    setState(() => _submitting = true);

    try {
      final annotatedB64 = await _renderAnnotatedScreenshot();
      if (!mounted) return;
      await widget.onSubmit(
        type: _selectedType,
        message: _descController.text.trim(),
        screenshotB64: annotatedB64,
      );
      if (mounted) Navigator.pop(context);
    } catch (e, stack) {
      gameLogger.e('FeedbackSheet: submit failed', error: e, stackTrace: stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send feedback — will retry when online.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<String> _renderAnnotatedScreenshot() async {
    // Decode the original screenshot
    final codec = await ui.instantiateImageCodec(widget.screenshotBytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImage(image, Offset.zero, Paint());

    // Draw annotations
    final paint = Paint()
      ..color = Colors.red
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final path in _drawPaths) {
      for (int i = 0; i < path.length - 1; i++) {
        if (path[i] != null && path[i + 1] != null) {
          // Scale draw coordinates from preview to image size
          final scaleX = image.width.toDouble() / _previewWidth;
          final scaleY = image.height.toDouble() / _previewHeight;
          canvas.drawLine(
            Offset(path[i]!.dx * scaleX, path[i]!.dy * scaleY),
            Offset(path[i + 1]!.dx * scaleX, path[i + 1]!.dy * scaleY),
            paint,
          );
        }
      }
    }

    final picture = recorder.endRecording();
    final rendered = await picture.toImage(image.width, image.height);
    final byteData = await rendered.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    rendered.dispose();

    if (byteData == null) return '';
    return base64Encode(byteData.buffer.asUint8List());
  }

  // Updated by LayoutBuilder on each build; read by `_renderAnnotatedScreenshot()`
  // to scale annotation coordinates from preview space to image space.
  double _previewWidth = 300;
  double _previewHeight = 200;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: kLyraInk,
        gradient: RadialGradient(
          center: const Alignment(0.0, -1.0),
          radius: 1.2,
          colors: [kLyraNebulaA.withValues(alpha: 0.6), Colors.transparent],
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
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: _previewWidth,
                        height: _previewHeight,
                        child: GestureDetector(
                          onPanStart: (d) {
                            setState(() {
                              _drawPaths.add([d.localPosition]);
                            });
                          },
                          onPanUpdate: (d) {
                            setState(() {
                              _drawPaths.last.add(d.localPosition);
                            });
                          },
                          onPanEnd: (_) {
                            _drawPaths.last.add(null);
                          },
                          child: CustomPaint(
                            foregroundPainter: _DrawPainter(_drawPaths),
                            child: Image.memory(
                              widget.screenshotBytes,
                              fit: BoxFit.cover,
                              width: _previewWidth,
                              height: _previewHeight,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                // Type picker
                Row(
                  children: [
                    _TypeButton(
                      label: 'Bug',
                      selected: _selectedType == 'bug',
                      onTap: () => setState(() => _selectedType = 'bug'),
                    ),
                    const SizedBox(width: 8),
                    _TypeButton(
                      label: 'Feature',
                      selected: _selectedType == 'feature',
                      onTap: () => setState(() => _selectedType = 'feature'),
                    ),
                    const SizedBox(width: 8),
                    _TypeButton(
                      label: 'Other',
                      selected: _selectedType == 'other',
                      onTap: () => setState(() => _selectedType = 'other'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Description field
                TextField(
                  controller: _descController,
                  maxLines: 3,
                  style: GoogleFonts.ibmPlexMono(fontSize: 13, color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Describe the issue...',
                    hintStyle: GoogleFonts.ibmPlexMono(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.06),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: kLyraAccent.withValues(alpha: 0.5)),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 20),
                // Submit button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _canSubmit ? _handleSubmit : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kLyraAccent,
                      foregroundColor: kLyraInk,
                      disabledBackgroundColor: kLyraAccent.withValues(alpha: 0.3),
                      disabledForegroundColor: kLyraInk.withValues(alpha: 0.5),
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
                            child: CircularProgressIndicator(strokeWidth: 2, color: kLyraInk),
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
            color: selected ? kLyraAccent.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.06),
            border: Border.all(
              color: selected ? kLyraAccent : Colors.white.withValues(alpha: 0.1),
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.ibmPlexMono(
              fontSize: 12,
              letterSpacing: 1,
              color: selected ? kLyraAccent : Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }
}

class _DrawPainter extends CustomPainter {
  final List<List<Offset?>> paths;
  _DrawPainter(this.paths);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final path in paths) {
      for (int i = 0; i < path.length - 1; i++) {
        if (path[i] != null && path[i + 1] != null) {
          canvas.drawLine(path[i]!, path[i + 1]!, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DrawPainter oldDelegate) => paths != oldDelegate.paths;
}
