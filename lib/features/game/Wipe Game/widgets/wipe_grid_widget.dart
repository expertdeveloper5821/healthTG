import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class WipeGridWidget extends StatefulWidget {
  final String imagePath;
  final int resetToken;
  final Offset leftHand;
  final Offset rightHand;
  final GlobalKey coordinateSpaceKey;

  const WipeGridWidget({
    super.key,
    required this.imagePath,
    required this.resetToken,
    required this.leftHand,
    required this.rightHand,
    required this.coordinateSpaceKey,
  });

  @override
  State<WipeGridWidget> createState() => _WipeGridWidgetState();
}

class _WipeGridWidgetState extends State<WipeGridWidget> {
  static const int _maxWipePoints = 1400;
  static const int _trimWipePoints = 300;
  static const double _brushSpacing = 12;
  static const double _pointSmoothing = 0.38;

  final List<_WipeStrokePoint> _wipePoints = [];
  final Map<int, Offset> _lastPointByHand = {};
  final Map<int, int> _strokeIdByHand = {};
  Offset _smoothedLeftHand = Offset.zero;
  Offset _smoothedRightHand = Offset.zero;
  ui.Image? _overlayImage;
  String? _loadedImagePath;
  int _wipeVersion = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadOverlayImage();
  }

  @override
  void didUpdateWidget(covariant WipeGridWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.imagePath != widget.imagePath) {
      _overlayImage = null;
      _loadedImagePath = null;
      _wipePoints.clear();
      _lastPointByHand.clear();
      _strokeIdByHand.clear();
      _wipeVersion++;
      _loadOverlayImage();
    }

    if (oldWidget.resetToken != widget.resetToken) {
      _wipePoints.clear();
      _lastPointByHand.clear();
      _strokeIdByHand.clear();
      _smoothedLeftHand = Offset.zero;
      _smoothedRightHand = Offset.zero;
      _wipeVersion++;
    }

    final leftChanged = _appendWipeStroke(
      rawPosition: _toLocalBrushPosition(widget.leftHand),
      smoothedPosition: _smoothedLeftHand,
      handId: 0,
      onSmooth: (position) => _smoothedLeftHand = position,
    );
    final rightChanged = _appendWipeStroke(
      rawPosition: _toLocalBrushPosition(widget.rightHand),
      smoothedPosition: _smoothedRightHand,
      handId: 1,
      onSmooth: (position) => _smoothedRightHand = position,
    );

    if (leftChanged || rightChanged) {
      _wipeVersion++;
      if (_wipePoints.length > _maxWipePoints) {
        _wipePoints.removeRange(0, _trimWipePoints);
      }
    }
  }

  void _loadOverlayImage() {
    if (_loadedImagePath == widget.imagePath) return;
    _loadedImagePath = widget.imagePath;

    final stream = AssetImage(
      widget.imagePath,
    ).resolve(createLocalImageConfiguration(context));

    late final ImageStreamListener listener;
    listener = ImageStreamListener((info, _) {
      stream.removeListener(listener);
      if (!mounted || _loadedImagePath != widget.imagePath) return;
      setState(() {
        _overlayImage = info.image;
        _wipeVersion++;
      });
    });

    stream.addListener(listener);
  }

  Offset _toLocalBrushPosition(Offset stackPosition) {
    if (stackPosition == Offset.zero) return Offset.zero;

    final gridBox = context.findRenderObject();
    final stackBox = widget.coordinateSpaceKey.currentContext
        ?.findRenderObject();
    if (gridBox is! RenderBox || stackBox is! RenderBox) {
      return Offset.zero;
    }

    if (!gridBox.hasSize || !stackBox.hasSize) return Offset.zero;

    final globalPosition = stackBox.localToGlobal(stackPosition);
    final localPosition = gridBox.globalToLocal(globalPosition);
    final gridBounds = Offset.zero & gridBox.size;
    if (!gridBounds.inflate(_brushSpacing).contains(localPosition)) {
      return Offset.zero;
    }

    return Offset(
      localPosition.dx.clamp(0.0, gridBox.size.width),
      localPosition.dy.clamp(0.0, gridBox.size.height),
    );
  }

  bool _appendWipeStroke({
    required Offset rawPosition,
    required Offset smoothedPosition,
    required int handId,
    required ValueChanged<Offset> onSmooth,
  }) {
    if (rawPosition == Offset.zero) {
      onSmooth(Offset.zero);
      _lastPointByHand.remove(handId);
      _strokeIdByHand[handId] = (_strokeIdByHand[handId] ?? 0) + 1;
      return false;
    }

    final nextPosition = smoothedPosition == Offset.zero
        ? rawPosition
        : Offset.lerp(smoothedPosition, rawPosition, _pointSmoothing) ??
              rawPosition;

    onSmooth(nextPosition);

    final strokeId = _strokeIdByHand[handId] ?? 0;
    final previousPoint = _lastPointByHand[handId];
    if (previousPoint == null) {
      _wipePoints.add(_WipeStrokePoint(nextPosition, handId, strokeId));
      _lastPointByHand[handId] = nextPosition;
      return true;
    }

    final distance = (nextPosition - previousPoint).distance;
    if (distance < _brushSpacing) return false;

    final steps = (distance / _brushSpacing).ceil().clamp(1, 8);
    for (var i = 1; i <= steps; i++) {
      final t = i / steps;
      final point = Offset.lerp(previousPoint, nextPosition, t);
      if (point != null) {
        _wipePoints.add(_WipeStrokePoint(point, handId, strokeId));
      }
    }

    _lastPointByHand[handId] = nextPosition;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: RepaintBoundary(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);

            return Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(widget.imagePath, fit: BoxFit.cover),
                CustomPaint(
                  size: size,
                  painter: _WipePainter(
                    wipePoints: _wipePoints,
                    imagePath: widget.imagePath,
                    overlayImage: _overlayImage,
                    repaintVersion: _wipeVersion,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _WipeStrokePoint {
  final Offset position;
  final int handId;
  final int strokeId;

  const _WipeStrokePoint(this.position, this.handId, this.strokeId);
}

class _WipePainter extends CustomPainter {
  static const double _brushRadius = 48;
  static const double _softEdge = 14;

  final List<_WipeStrokePoint> wipePoints;
  final String imagePath;
  final ui.Image? overlayImage;
  final int repaintVersion;

  const _WipePainter({
    required this.wipePoints,
    required this.imagePath,
    required this.overlayImage,
    required this.repaintVersion,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;

    canvas.saveLayer(bounds, Paint());

    final image = overlayImage;
    if (image != null) {
      final source = _coverSourceRect(image, size);
      canvas.saveLayer(
        bounds,
        Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
      );
      canvas.drawImageRect(image, source, bounds, Paint());
      canvas.restore();
    }

    canvas.drawRect(
      bounds,
      Paint()..color = Colors.black.withValues(alpha: 0.28),
    );

    if (wipePoints.isNotEmpty) {
      final clearPaint = Paint()
        ..blendMode = BlendMode.clear
        ..style = PaintingStyle.stroke
        ..strokeWidth = _brushRadius * 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, _softEdge);

      final dotPaint = Paint()
        ..blendMode = BlendMode.clear
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, _softEdge);

      final previousByStroke = <String, Offset>{};
      for (var i = 0; i < wipePoints.length; i++) {
        final current = wipePoints[i];
        final strokeKey = '${current.handId}:${current.strokeId}';
        final previous = previousByStroke[strokeKey];

        if (previous != null) {
          canvas.drawLine(previous, current.position, clearPaint);
        } else {
          canvas.drawCircle(current.position, _brushRadius, dotPaint);
        }

        previousByStroke[strokeKey] = current.position;
      }
    }

    canvas.restore();
  }

  Rect _coverSourceRect(ui.Image image, Size outputSize) {
    final inputSize = Size(image.width.toDouble(), image.height.toDouble());
    final inputRatio = inputSize.width / inputSize.height;
    final outputRatio = outputSize.width / outputSize.height;

    if (inputRatio > outputRatio) {
      final sourceWidth = inputSize.height * outputRatio;
      final left = (inputSize.width - sourceWidth) / 2;
      return Rect.fromLTWH(left, 0, sourceWidth, inputSize.height);
    }

    final sourceHeight = inputSize.width / outputRatio;
    final top = (inputSize.height - sourceHeight) / 2;
    return Rect.fromLTWH(0, top, inputSize.width, sourceHeight);
  }

  @override
  bool shouldRepaint(covariant _WipePainter oldDelegate) {
    return oldDelegate.repaintVersion != repaintVersion ||
        oldDelegate.imagePath != imagePath;
  }
}
