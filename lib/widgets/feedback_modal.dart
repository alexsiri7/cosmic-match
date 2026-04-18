import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../game/theme/app_theme.dart';
import '../models/feedback_item.dart';
import '../screens/modals.dart';
import '../services/feedback_queue_service.dart';
import '../services/github_feedback_client.dart';

class FeedbackModal extends StatefulWidget {
  final Uint8List screenshot;
  final FeedbackQueueService queue;
  final GitHubFeedbackClient client;

  const FeedbackModal({
    super.key,
    required this.screenshot,
    required this.queue,
    required this.client,
  });

  @override
  State<FeedbackModal> createState() => _FeedbackModalState();
}

class _FeedbackModalState extends State<FeedbackModal> {
  final _descriptionController = TextEditingController();
  final List<Offset?> _points = [];
  bool _isSubmitting = false;
  bool _drawMode = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<Uint8List> _renderAnnotatedScreenshot() async {
    final codec = await ui.instantiateImageCodec(widget.screenshot);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImage(image, Offset.zero, Paint());

    if (_points.isNotEmpty) {
      final paint = Paint()
        ..color = kLyraAccent
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      for (int i = 0; i < _points.length - 1; i++) {
        if (_points[i] != null && _points[i + 1] != null) {
          // Scale points from widget coordinates to image coordinates
          final scaleX = image.width / _imageDisplaySize.width;
          final scaleY = image.height / _imageDisplaySize.height;
          canvas.drawLine(
            Offset(_points[i]!.dx * scaleX, _points[i]!.dy * scaleY),
            Offset(_points[i + 1]!.dx * scaleX, _points[i + 1]!.dy * scaleY),
            paint,
          );
        }
      }
    }

    final picture = recorder.endRecording();
    final rendered =
        await picture.toImage(image.width, image.height);
    final byteData =
        await rendered.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    rendered.dispose();
    return byteData!.buffer.asUint8List();
  }

  Size _imageDisplaySize = Size.zero;

  Future<void> _submit() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final annotatedPng = await _renderAnnotatedScreenshot();
      final item = FeedbackItem(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        timestamp: DateTime.now(),
        description: _descriptionController.text,
        screenshotBase64: base64Encode(annotatedPng),
      );

      await widget.queue.enqueue(item);

      if (!widget.client.isAvailable) {
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Feedback queued — token not configured')),
          );
        }
        return;
      }

      try {
        final imageUrl = await widget.client.uploadImage(item.id, annotatedPng);
        final issueUrl = await widget.client.createIssue(
            item.description, imageUrl);
        await widget.queue.markUploaded(item.id, issueUrl);
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Feedback submitted — thank you!')),
          );
        }
      } on FeedbackClientException {
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Queued — will submit when online')),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ModalShell(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'SEND FEEDBACK',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 2.5,
                color: Colors.white54,
              ),
            ),
            const SizedBox(height: 12),
            // Screenshot preview with annotation overlay
            LayoutBuilder(
              builder: (context, constraints) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: GestureDetector(
                    onPanStart: _drawMode
                        ? (d) => setState(() => _points.add(d.localPosition))
                        : null,
                    onPanUpdate: _drawMode
                        ? (d) => setState(() => _points.add(d.localPosition))
                        : null,
                    onPanEnd: _drawMode
                        ? (_) => setState(() => _points.add(null))
                        : null,
                    child: Stack(
                      children: [
                        _ImageSizeCapture(
                          onSizeChanged: (size) {
                            if (_imageDisplaySize != size) {
                              setState(() => _imageDisplaySize = size);
                            }
                          },
                          child: Image.memory(
                            widget.screenshot,
                            width: constraints.maxWidth,
                            fit: BoxFit.fitWidth,
                          ),
                        ),
                        if (_imageDisplaySize != Size.zero)
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _AnnotationPainter(_points),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            // Draw mode toggle
            Row(
              children: [
                IconButton(
                  onPressed: () => setState(() => _drawMode = !_drawMode),
                  icon: Icon(
                    Icons.edit,
                    size: 18,
                    color: _drawMode ? kLyraAccent : Colors.white54,
                  ),
                ),
                if (_points.isNotEmpty)
                  IconButton(
                    onPressed: () => setState(() => _points.clear()),
                    icon: const Icon(Icons.clear, size: 18, color: Colors.white54),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // Description
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              style: const TextStyle(fontSize: 13, color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Describe the issue...',
                hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4), fontSize: 13),
                filled: true,
                fillColor: kLyraInk,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Privacy disclaimer
            Text(
              'Your screenshot may include game data. Submitted feedback is publicly visible as a GitHub issue.',
              style: TextStyle(
                  fontSize: 10, color: Colors.white.withValues(alpha: 0.4)),
            ),
            const SizedBox(height: 12),
            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _isSubmitting ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.2)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(100)),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kLyraAccent,
                      foregroundColor: kLyraInk,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(100)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Submit'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageSizeCapture extends StatefulWidget {
  final Widget child;
  final ValueChanged<Size> onSizeChanged;

  const _ImageSizeCapture({required this.child, required this.onSizeChanged});

  @override
  State<_ImageSizeCapture> createState() => _ImageSizeCaptureState();
}

class _ImageSizeCaptureState extends State<_ImageSizeCapture> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reportSize());
  }

  void _reportSize() {
    final box = context.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      widget.onSizeChanged(box.size);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _AnnotationPainter extends CustomPainter {
  final List<Offset?> points;

  _AnnotationPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = kLyraAccent
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AnnotationPainter oldDelegate) => true;
}
