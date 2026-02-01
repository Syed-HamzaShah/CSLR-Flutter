import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'dart:math';

class SignLanguageService {
  bool _isModelLoaded = false;

  /// Loads the TFLite model.
  /// Currently a mock implementation.
  Future<void> loadModel() async {
    debugPrint("Loading TFLite Model...");
    // Simulate loading delay
    await Future.delayed(const Duration(seconds: 2));
    _isModelLoaded = true;
    debugPrint("TFLite Model Loaded Successfully.");
  }

  /// Runs inference on a camera frame.
  /// Returns a mock prediction for the prototype.
  String runInference(CameraImage cameraImage) {
    if (!_isModelLoaded) {
      return "Loading...";
    }

    // Mock inference logic
    final List<String> responses = [
      "Hello",
      "Thank You",
      "Yes",
      "No",
      "Good Morning",
      "How are you?",
      "Nice to meet you"
    ];
    
    // Return a random response to simulate detection
    return responses[Random().nextInt(responses.length)];
  }
}
