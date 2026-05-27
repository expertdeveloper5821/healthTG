import 'dart:async';
import 'dart:math';
import 'package:demo_p/health_screen.dart';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:android_intent_plus/android_intent.dart';
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  double angle = 0.0;
  double baseAngle = 0.0;
  double relativeAngle = 0.0;
  bool isProcessing = false;
  double? previousVolume;
  String postureStatus = "Calibrating...";
  String distanceStatus = "Detecting...";
  double smoothDistance = 0.0;
  bool isExerciseMode = false;
  bool isCalibrated = false;

  StreamSubscription? sensorSub;

 
  CameraController? cameraController;
  bool isCameraInitialized = false;

  final FaceDetector faceDetector = FaceDetector(
    options: FaceDetectorOptions(),
  );

  @override
  void initState() {
    super.initState();
    startSensor();
    initCamera();
  }
void openDNDSettings() {
  const intent = AndroidIntent(
    action: 'android.settings.NOTIFICATION_POLICY_ACCESS_SETTINGS',
  );
  intent.launch();
}

  void startSensor() {
    sensorSub?.cancel();

    double lastStableAngle = 0.0;

    sensorSub = accelerometerEvents.listen((event) {
      double x = event.x;
      double y = event.y;
      double z = event.z;

      double calculatedAngle =
          atan2(y, sqrt(x * x + z * z)) * (180 / pi);


      angle = 0.9 * angle + 0.1 * calculatedAngle;

   
      if ((angle - lastStableAngle).abs() < 1.0) {
        return;
      }
      lastStableAngle = angle;

  
      if (!isCalibrated) {
        baseAngle = angle;
        isCalibrated = true;
        debugPrint(" BASELINE SET: $baseAngle");
      }


      relativeAngle = angle - baseAngle;

      String newPosture;

      if (relativeAngle.abs() > 40) {
        newPosture = " Bad Posture";
      } else if (relativeAngle.abs() > 20) {
        newPosture = " Slight Tilt";
      } else {
        newPosture = " Good Posture";
      }

 
    

      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          setState(() {
            postureStatus = newPosture;
          });
        }
      });
    });
  }

  Future<void> initCamera() async {
    final cameras = await availableCameras();

    final frontCamera = cameras.firstWhere(
      (cam) => cam.lensDirection == CameraLensDirection.front,
    );

    cameraController = CameraController(
      frontCamera,
      ResolutionPreset.low,
      enableAudio: false,
    );

    await cameraController!.initialize();

    setState(() {
      isCameraInitialized = true;
    });

    startImageStream();
  }

 void startImageStream() {
  cameraController!.startImageStream((CameraImage image) async {
    if (isProcessing) return;
    isProcessing = true;

    try {

      if (image.format.group != ImageFormatGroup.yuv420) {
        isProcessing = false;
        return;
      }

     final rotation = InputImageRotation.rotation0deg;

    final bytes = WriteBuffer();

for (final plane in image.planes) {
  bytes.putUint8List(plane.bytes);
}

final allBytes = bytes.done().buffer.asUint8List();

final inputImage = InputImage.fromBytes(
  bytes: allBytes,
  metadata: InputImageMetadata(
    size: Size(image.width.toDouble(), image.height.toDouble()),
    rotation: rotation,
format: InputImageFormat.nv21,
    bytesPerRow: image.planes.first.bytesPerRow,
  ),
);
      final faces = await faceDetector.processImage(inputImage);

      if (faces.isNotEmpty) {
        final face = faces.first;

        double faceWidth = face.boundingBox.width;
        double imageWidth = image.width.toDouble();

   
       double raw = faceWidth / imageWidth;


smoothDistance = 0.8 * smoothDistance + 0.2 * raw;

debugPrint("RAW: $raw");
debugPrint("SMOOTH: $smoothDistance");

String newDistance;


if (smoothDistance > 0.28) {
  newDistance = " Too Close";
} else if (smoothDistance > 0.15) {
  newDistance = " Normal Distance";
} else {
  newDistance = " Too Far";
}

       if (mounted) {
  setState(() {
    distanceStatus = newDistance;
  });
}
      } else {
        setState(() {
          distanceStatus = "No Face Detected";
        });
      }
    } catch (e) {
      debugPrint("Camera error: $e");
    }

    await Future.delayed(const Duration(milliseconds: 150));
    isProcessing = false;
  });
}
void toggleExerciseMode() async {
  if (!isExerciseMode) {
 
    previousVolume = await FlutterVolumeController.getVolume();


    await FlutterVolumeController.setVolume(0.0);

   
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.cancel();
    }

  
    openDNDSettings();

    setState(() {
      isExerciseMode = true;
    });

  } else {
   
    if (previousVolume != null) {
      await FlutterVolumeController.setVolume(previousVolume!);
    }

    setState(() {
      isExerciseMode = false;
    });
  }
}

  @override
  void dispose() {
    sensorSub?.cancel();
    cameraController?.dispose();
    faceDetector.close();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Posture Monitor"),
        centerTitle: true,
      ),
      body: Column(
        children: [
          if (isCameraInitialized)
            SizedBox(
              height: 200,
              child: CameraPreview(cameraController!),
            ),

          const SizedBox(height: 20),

          Text(
            "Angle: ${angle.toStringAsFixed(2)}°",
            style: const TextStyle(fontSize: 22),
          ),

          Text(
            "Relative: ${relativeAngle.toStringAsFixed(2)}°",
            style: const TextStyle(fontSize: 18),
          ),

          const SizedBox(height: 10),

          Text(
            postureStatus,
            style: const TextStyle(fontSize: 20),
          ),

          const SizedBox(height: 20),

          Text(
            "Distance: $distanceStatus",
            style: const TextStyle(fontSize: 20),
          ),

          const SizedBox(height: 20),

          SwitchListTile(
            title: const Text("Exercise Mode"),
            value: isExerciseMode,
            onChanged: (value) {
              toggleExerciseMode();
            },
          ),
        ],
      ),
  
  bottomNavigationBar: Padding(
    padding: const EdgeInsets.all(24),
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => HealthScreen(),
          ),
        );
      },
      child: const Text(
        "Open Health",
        style: TextStyle(fontSize: 18),
      ),
    ),
  ),

    );
  }
}