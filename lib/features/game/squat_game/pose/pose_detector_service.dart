import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class PoseFrame {
  final List<Pose> poses;
  final Size imageSize;
  final DateTime capturedAt;

  const PoseFrame({
    required this.poses,
    required this.imageSize,
    required this.capturedAt,
  });
}

class SquatPoseDetectorService {
  CameraController? controller;
  bool isInitialized = false;

  ValueChanged<PoseFrame>? onPoseFrame;
  ValueChanged<Object>? onError;

  final PoseDetector _poseDetector = PoseDetector(
    options: PoseDetectorOptions(
      model: PoseDetectionModel.accurate,
      mode: PoseDetectionMode.stream,
    ),
  );

  bool _isDisposed = false;
  bool _isProcessingFrame = false;
  DateTime? _lastProcessedAt;
  int _frameCounter = 0;
  bool _metadataLogged = false;

  // 100 ms gives ~10 fps to ML Kit — enough for smooth stream-mode tracking
  static const Duration frameThrottle = Duration(milliseconds: 100);

  Future<void> initialize() async {
    if (_isDisposed || isInitialized) return;

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException('no_camera', 'No camera devices were found.');
      }

      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isIOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.nv21,
      );

      await controller!.initialize();
      if (_isDisposed) {
        await controller?.dispose();
        return;
      }

      debugPrint(
        '[SquatCamera] Initialized — preview: ${controller!.value.previewSize} '
        'sensor: ${frontCamera.sensorOrientation}°',
      );

      await controller!.startImageStream(_processCameraImage);
      isInitialized = true;
    } catch (error) {
      debugPrint('[SquatCamera] Init error: $error');
      onError?.call(error);
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isDisposed || _isProcessingFrame) return;
    if (!(controller?.value.isStreamingImages ?? false)) return;

    _frameCounter++;

    final now = DateTime.now();
    if (_lastProcessedAt != null &&
        now.difference(_lastProcessedAt!) < frameThrottle) {
      return;
    }

    final camera = controller?.description;
    if (camera == null) return;

    final inputImage = _inputImageFromCameraImage(image, camera);
    if (inputImage == null) return;

    _isProcessingFrame = true;
    try {
      final poses = await _poseDetector.processImage(inputImage);
      if (_isDisposed) return;

      _lastProcessedAt = DateTime.now();
      _logPoseResult(poses, image);

      onPoseFrame?.call(
        PoseFrame(
          poses: poses,
          imageSize: Size(image.width.toDouble(), image.height.toDouble()),
          capturedAt: now,
        ),
      );
    } catch (error) {
      debugPrint('[SquatPose] Processing error: $error');
      onError?.call(error);
    } finally {
      _isProcessingFrame = false;
    }
  }

  InputImage? _inputImageFromCameraImage(
    CameraImage image,
    CameraDescription camera,
  ) {
    if (image.planes.isEmpty) return null;

    final rotation = InputImageRotationValue.fromRawValue(
      camera.sensorOrientation,
    );
    if (rotation == null) return null;

    if (Platform.isIOS) {
      // iOS: single BGRA8888 plane; bytesPerRow may include hardware padding
      // but ML Kit uses it as the row stride so pass it as-is.
      if (!_metadataLogged) {
        _metadataLogged = true;
        debugPrint(
          '[SquatImage] First frame (iOS) — '
          '${image.width}x${image.height} '
          'rot:${rotation.rawValue}° fmt:bgra8888 '
          'bpr:${image.planes.first.bytesPerRow}',
        );
      }
      return InputImage.fromBytes(
        bytes: image.planes.first.bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.bgra8888,
          bytesPerRow: image.planes.first.bytesPerRow,
        ),
      );
    }

    // Android: build a clean NV21 buffer with no row padding.
    // The simple plane-concatenation approach corrupts NV21 whenever
    // bytesPerRow > width (hardware-aligned stride) or when the device
    // returns 3-plane YUV420 instead of 2-plane NV21.  ML Kit then
    // receives the wrong number of bytes, fails to parse the image, and
    // logs "Using NORM_RECT without IMAGE_DIMENSIONS" → zero poses detected.
    final nv21 = _buildCleanNV21(image);
    if (nv21 == null) return null;

    if (!_metadataLogged) {
      _metadataLogged = true;
      final expected = image.width * image.height * 3 ~/ 2;
      debugPrint(
        '[SquatImage] First frame (Android) — '
        '${image.width}x${image.height} '
        'rot:${rotation.rawValue}° fmt:nv21 '
        'planes:${image.planes.length} '
        'nv21Bytes:${nv21.length} expected:$expected '
        'match:${nv21.length == expected} '
        'y_bpr:${image.planes.first.bytesPerRow}',
      );
    }

    return InputImage.fromBytes(
      bytes: nv21,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21,
        // bytesPerRow must match the stride in the buffer we pass.
        // Our clean NV21 has no padding, so stride == width.
        bytesPerRow: image.width,
      ),
    );
  }

  /// Builds a correctly-sized NV21 byte buffer from a [CameraImage].
  ///
  /// Handles three cases:
  ///  • 2-plane NV21/NV12  (bytesPerRow may be padded)
  ///  • 3-plane YUV420_888 (must interleave V,U manually)
  ///  • 1-plane raw        (pass through unchanged)
  Uint8List? _buildCleanNV21(CameraImage image) {
    final w = image.width;
    final h = image.height;
    final planes = image.planes;

    final expectedSize = w * h * 3 ~/ 2;
    final out = Uint8List(expectedSize);

    // ── Y plane ──────────────────────────────────────────────────────────────
    final yPlane = planes[0];
    final yBpr = yPlane.bytesPerRow;
    final yData = yPlane.bytes;

    if (yBpr == w && yData.length >= w * h) {
      out.setRange(0, w * h, yData);
    } else {
      for (int row = 0; row < h; row++) {
        final src = row * yBpr;
        final dst = row * w;
        if (src + w > yData.length) break;
        out.setRange(dst, dst + w, yData, src);
      }
    }

    final uvStart = w * h;
    final uvRows = h ~/ 2;

    if (planes.length == 1) {
      // Single plane (rare fallback) — nothing to append for chroma.
      return out;
    }

    if (planes.length == 2) {
      // ── Semi-planar NV21 / NV12 (2 planes) ────────────────────────────────
      // The camera plugin delivers VU-interleaved bytes in planes[1] for NV21.
      // Strip any per-row padding exactly the same way as the Y plane.
      final uvPlane = planes[1];
      final uvBpr = uvPlane.bytesPerRow;
      final uvData = uvPlane.bytes;

      if (uvBpr == w && uvData.length >= w * uvRows) {
        out.setRange(uvStart, uvStart + w * uvRows, uvData);
      } else {
        for (int row = 0; row < uvRows; row++) {
          final src = row * uvBpr;
          final dst = uvStart + row * w;
          if (src + w > uvData.length) break;
          out.setRange(dst, dst + w, uvData, src);
        }
      }
      return out;
    }

    // ── Fully-planar YUV420 (3 planes) ────────────────────────────────────
    // Interleave as NV21: V byte first, then U byte, for each chroma sample.
    final uPlane = planes[1]; // Cb
    final vPlane = planes[2]; // Cr
    final uData = uPlane.bytes;
    final vData = vPlane.bytes;
    final uBpr = uPlane.bytesPerRow;
    final vBpr = vPlane.bytesPerRow;
    final uStride = uPlane.bytesPerPixel ?? 1;
    final vStride = vPlane.bytesPerPixel ?? 1;
    final uvCols = w ~/ 2;

    for (int row = 0; row < uvRows; row++) {
      for (int col = 0; col < uvCols; col++) {
        final uIdx = row * uBpr + col * uStride;
        final vIdx = row * vBpr + col * vStride;
        final dst = uvStart + row * w + col * 2;
        if (dst + 1 >= expectedSize) break;
        if (vIdx < vData.length) out[dst] = vData[vIdx];
        if (uIdx < uData.length) out[dst + 1] = uData[uIdx];
      }
    }
    return out;
  }

  void _logPoseResult(List<Pose> poses, CameraImage image) {
    if (_frameCounter % 30 != 0) return;

    if (poses.isEmpty) {
      debugPrint('[SquatPose] frame:$_frameCounter — no pose detected');
      return;
    }

    final pose = poses.first;
    final landmarks = pose.landmarks;
    final reliableCount =
        landmarks.values.where((l) => l.likelihood >= 0.35).length;
    final avgConf = landmarks.isEmpty
        ? 0.0
        : landmarks.values
                .map((l) => l.likelihood)
                .fold(0.0, (a, b) => a + b) /
            landmarks.length;

    debugPrint(
      '[SquatPose] frame:$_frameCounter — '
      'poses:${poses.length} '
      'landmarks:${landmarks.length} '
      'reliable(≥0.35):$reliableCount '
      'avgConf:${avgConf.toStringAsFixed(2)} '
      'img:${image.width}x${image.height}',
    );
  }

  Future<void> dispose() async {
    _isDisposed = true;
    onPoseFrame = null;
    onError = null;

    try {
      if (controller?.value.isStreamingImages ?? false) {
        await controller?.stopImageStream();
      }
    } catch (error) {
      debugPrint('[SquatCamera] Stream stop error: $error');
    }

    await controller?.dispose();
    controller = null;
    await _poseDetector.close();
    isInitialized = false;
  }
}
