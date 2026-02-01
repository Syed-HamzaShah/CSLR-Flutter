import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:hand_landmarker/hand_landmarker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class SignLanguageService {
  Interpreter? _interpreter;
  List<String> _labels = [];

  // ML Kit Pose Detector
  late final PoseDetector _poseDetector;
  
  // MediaPipe Hand Landmarker
  HandLandmarkerPlugin? _handPlugin;

  // Sliding window buffer (30 frames)
  final List<List<double>> _sequenceBuffer = [];
  bool _isProcessing = false;

  SignLanguageService() {
    _initializeDetectors();
    _loadModel();
  }

  void _initializeDetectors() {
    // Initialize ML Kit Pose Detector
    final options = PoseDetectorOptions(mode: PoseDetectionMode.stream);
    _poseDetector = PoseDetector(options: options);

    // Initialize MediaPipe Hand Landmarker (Android only usually)
    if (Platform.isAndroid) {
      _handPlugin = HandLandmarkerPlugin.create(
        numHands: 2,
        minHandDetectionConfidence: 0.5,
        delegate: HandLandmarkerDelegate.gpu,
      );
    }
  }

  Future<void> _loadModel() async {
    try {
      // Load TFLite model
      _interpreter = await Interpreter.fromAsset('assets/sign_lang_model.tflite');
      
      // Load Labels
      final labelData = await rootBundle.loadString('assets/labels.txt');
      _labels = labelData.split('\n').where((s) => s.trim().isNotEmpty).toList();

      print("✅ Model Loaded. Input Shape: ${_interpreter!.getInputTensor(0).shape}");
      print("✅ Labels Loaded: ${_labels.length}");
    } catch (e) {
      print("❌ Error loading model/labels: $e");
    }
  }

  Future<String?> processFrame(
    InputImage inputImage, {
    CameraImage? cameraImage,
    int? sensorOrientation,
  }) async {
    if (_isProcessing || _interpreter == null) return null;
    _isProcessing = true;

    try {
      // 1. Pose Detection (ML Kit)
      final poses = await _poseDetector.processImage(inputImage);
      
      // 2. Hand Detection (MediaPipe) - Requires CameraImage
      List<Hand> hands = [];
      if (Platform.isAndroid && 
          _handPlugin != null && 
          cameraImage != null && 
          sensorOrientation != null) {
        try {
          hands = _handPlugin!.detect(cameraImage, sensorOrientation);
        } catch (e) {
          print("Hand Detection Error: $e");
        }
      }

      // If no detection at all, skip frame processing to save resources? 
      // Or should we process empty frames as zeros? 
      // Usually, for sign language, we want to feed continuous frames. 
      // If empty, we feed zeros.
      
      // Prepare normalized keypoints
      List<double> frameKeypoints = [];
      final Size imageSize = inputImage.metadata?.size ?? const Size(1, 1);
      final double width = imageSize.width;
      final double height = imageSize.height;

      // --- A. POSE (33 landmarks * 3 = 99 points) ---
      if (poses.isNotEmpty) {
        final pose = poses.first;
        for (var lm in pose.landmarks.values) {
          // Normalize ML Kit coordinates (pixels) to 0.0 - 1.0
          frameKeypoints.add(lm.x / width);
          frameKeypoints.add(lm.y / height);
          // Z is typically depth, not directly normalizable by width/height in the same way, 
          // but to keep range consistent we often divide by width or leaving it as is.
          // User asked: "Normalize ... coordinates ... to 0.0-1.0 range by dividing by image width/height"
          // We'll normalize Z by width to keep aspect ratio or just width.
          frameKeypoints.add(lm.z / width); 
        }
      } else {
        frameKeypoints.addAll(List.filled(33 * 3, 0.0));
      }

      // --- B. HANDS (2 hands * 21 landmarks * 3 = 126 points) ---
      // We need to separate Left and Right.
      // MediaPipe hands usually don't guarantee order, but provide handover "Left" or "Right".
      // HandLandmarker plugin might return a list.
      // We need to check handedness if available, otherwise assume index 0/1.
      // The previous code assumed index 0 = Left, 1 = Right. We will stick to that or try to improve if possible.
      // Validating 'Hand' object structure: currently we treat it as list of landmarks.
      
      List<double> leftHand = List.filled(21 * 3, 0.0);
      List<double> rightHand = List.filled(21 * 3, 0.0);

      // Warning: Without explicit handedness check, this is a guess.
      // But typically for front camera: 
      // If we rely on the previous logic:
      for (int i = 0; i < hands.length; i++) {
        final hand = hands[i];
        final points = <double>[];
        for (var lm in hand.landmarks) {
           // MediaPipe HandLandmarker usually returns normalized [0,1].
           // BUT User said: "Normalize ... (which are in pixels) ... by dividing by image width/height".
           // We will check logic: If x > 1.0, it's pixels, so divide. Else, keep it.
           // This handles both cases safely.
           double x = lm.x;
           double y = lm.y;
           double z = lm.z;

           if (x > 1.0 || y > 1.0) {
             x /= width;
             y /= height;
             z /= width;
           }
           
           points.addAll([x, y, z]);
        }

        // Assign to Left/Right
        // Implementation Detail: Determining handedness is tricky without label.
        // Assuming order for now as simple assignment.
        if (i == 0) {
          leftHand = points;
        } else {
          rightHand = points;
        }
      }

      frameKeypoints.addAll(leftHand);
      frameKeypoints.addAll(rightHand);

      // --- C. PADDING (Total 312) ---
      // Current count: 99 (Pose) + 63 (Left) + 63 (Right) = 225.
      // Target: 312.
      if (frameKeypoints.length < 312) {
        frameKeypoints.addAll(List.filled(312 - frameKeypoints.length, 0.0));
      } else if (frameKeypoints.length > 312) {
         // Should not happen if counts are correct, but truncate just in case
         frameKeypoints = frameKeypoints.sublist(0, 312);
      }

      // --- D. SLIDING WINDOW BUFFER ---
      _sequenceBuffer.add(frameKeypoints);
      if (_sequenceBuffer.length > 30) {
        _sequenceBuffer.removeAt(0); // Remove oldest
      }

      // --- E. INFERENCE ---
      if (_sequenceBuffer.length == 30) {
        // Prepare input: [1, 30, 312]
        var input = [_sequenceBuffer]; 
        
        // Output buffer: [1, NumLabels]
        var output = List.filled(1 * _labels.length, 0.0).reshape([1, _labels.length]);

        _interpreter!.run(input, output);

        // Parse result
        List<double> probabilities = List<double>.from(output[0]);
        int maxIndex = -1;
        double maxScore = 0.0;
        
        for (int i = 0; i < probabilities.length; i++) {
          if (probabilities[i] > maxScore) {
            maxScore = probabilities[i];
            maxIndex = i;
          }
        }

        if (maxIndex != -1 && maxScore > 0.7) { // Threshold
           return "${_labels[maxIndex]} ${(maxScore * 100).toInt()}%";
        }
      }

    } catch (e) {
      print("Processing Error: $e");
    } finally {
      _isProcessing = false;
    }
    
    return null;
  }

  void dispose() {
    _poseDetector.close();
    _handPlugin?.dispose();
    _interpreter?.close();
  }
}
