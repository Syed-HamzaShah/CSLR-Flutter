import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:google_mlkit_hand_detection/google_mlkit_hand_detection.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class SignLanguageService {
  Interpreter? _interpreter;
  List<String> _labels = [];
  
  // Detectors
  late final PoseDetector _poseDetector;
  late final HandDetector _handDetector;

  // Buffer: Stores last 30 frames. Each frame has 312 numbers.
  final List<List<double>> _sequenceBuffer = [];
  bool _isProcessing = false;

  SignLanguageService() {
    _initializeDetectors();
    _loadModel();
  }

  void _initializeDetectors() {
    // Pose: Stream mode for speed
    _poseDetector = PoseDetector(options: PoseDetectorOptions(mode: PoseDetectionMode.stream));
    // Hands: Stream mode, confidence 0.5
    _handDetector = HandDetector(options: HandDetectorOptions(mode: HandDetectionMode.stream, minHandDetectionConfidence: 0.5));
  }

  Future<void> _loadModel() async {
    try {
      // 1. Load the Model
      _interpreter = await Interpreter.fromAsset('assets/sign_lang_model.tflite');
      
      // 2. Load the Labels (100 words)
      final labelData = await rootBundle.loadString('assets/labels.txt');
      _labels = labelData.split('\n').where((s) => s.trim().isNotEmpty).toList();
      
      print("✅ Model Loaded. Expecting input: ${_interpreter!.getInputTensor(0).shape}");
      print("✅ Dictionary Loaded: ${_labels.length} words");
    } catch (e) {
      print("❌ Error loading model/labels: $e");
    }
  }

  Future<String?> processFrame(InputImage inputImage) async {
    if (_isProcessing || _interpreter == null) return null;
    _isProcessing = true;

    try {
      // 1. Run ML Kit Detectors
      final poses = await _poseDetector.processImage(inputImage);
      final hands = await _handDetector.processImage(inputImage);

      // Optimization: If no humans found, don't predict
      if (poses.isEmpty && hands.isEmpty) {
        _isProcessing = false;
        return null;
      }

      // 2. Extract Keypoints (Matches Python: Pose(99) + Left(63) + Right(63) + Pad = 312)
      List<double> frameKeypoints = [];

      // --- A. POSE (33 landmarks * 3 coords = 99) ---
      if (poses.isNotEmpty) {
        for (var lm in poses.first.landmarks.values) {
          frameKeypoints.addAll([lm.x, lm.y, lm.z]);
        }
      } else {
        frameKeypoints.addAll(List.filled(33 * 3, 0.0));
      }

      // --- B. HANDS (Left & Right) ---
      List<double> leftHand = List.filled(21 * 3, 0.0);
      List<double> rightHand = List.filled(21 * 3, 0.0);

      for (var hand in hands) {
        List<double> points = [];
        for (var lm in hand.landmarks.values) {
          // ML Kit often lacks Z for hands, default to 0.0
          points.addAll([lm.x, lm.y, 0.0]); 
        }

        if (hand.type == HandType.left) {
          leftHand = points;
        } else {
          rightHand = points;
        }
      }
      
      frameKeypoints.addAll(leftHand);  // +63
      frameKeypoints.addAll(rightHand); // +63

      // --- C. PADDING (Total must be 312) ---
      // Current: 99 + 63 + 63 = 225. Missing: 87.
      if (frameKeypoints.length < 312) {
        frameKeypoints.addAll(List.filled(312 - frameKeypoints.length, 0.0));
      }

      // 3. Update Sliding Window Buffer
      _sequenceBuffer.add(frameKeypoints);
      
      // Keep only last 30 frames
      if (_sequenceBuffer.length > 30) {
        _sequenceBuffer.removeAt(0);
      }

      // 4. Run Inference (Only if we have 30 frames)
      if (_sequenceBuffer.length == 30) {
        // Input: [1, 30, 312]
        var input = [_sequenceBuffer]; 
        
        // Output: [1, 100]
        var output = List.filled(1 * _labels.length, 0.0).reshape([1, _labels.length]);

        _interpreter!.run(input, output);

        // 5. Decode Output
        List<double> probabilities = List<double>.from(output[0]);
        
        // Find Max
        double maxScore = 0.0;
        int maxIndex = -1;
        
        for (int i = 0; i < probabilities.length; i++) {
          if (probabilities[i] > maxScore) {
            maxScore = probabilities[i];
            maxIndex = i;
          }
        }

        _isProcessing = false;
        
        // Threshold: 85% Confidence
        if (maxScore > 0.85) {
          return "${_labels[maxIndex]} ${(maxScore * 100).toInt()}%";
        }
      }
    } catch (e) {
      print("Inference Error: $e");
    }

    _isProcessing = false;
    return null;
  }

  void dispose() {
    _poseDetector.close();
    _handDetector.close();
    _interpreter?.close();
  }
}