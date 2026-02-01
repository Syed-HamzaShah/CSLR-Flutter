import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import '../../../services/sign_language_service.dart';

class SignInputScreen extends StatefulWidget {
  const SignInputScreen({super.key});

  @override
  State<SignInputScreen> createState() => _SignInputScreenState();
}

class _SignInputScreenState extends State<SignInputScreen> {
  CameraController? _controller;
  final SignLanguageService _service = SignLanguageService();
  String _detectedWord = "Waiting...";
  bool _isProcessingFrame = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    // Use Front Camera
    final frontCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      frontCamera,
      ResolutionPreset.low, // Low resolution = Faster FPS for ML
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid 
          ? ImageFormatGroup.nv21 
          : ImageFormatGroup.bgra8888,
    );

    await _controller!.initialize();

    // Start Streaming
    _controller!.startImageStream((CameraImage image) async {
      if (_isProcessingFrame) return;
      _isProcessingFrame = true;

      try {
        final inputImage = _inputImageFromCameraImage(image);
        if (inputImage != null) {
          final result = await _service.processFrame(inputImage);
          if (result != null) {
            setState(() {
              _detectedWord = result;
            });
          }
        }
      } catch (e) {
        print("Frame Error: $e");
      } finally {
        _isProcessingFrame = false;
      }
    });

    if (mounted) setState(() {});
  }

  // Helper: Convert raw Camera bytes to ML Kit InputImage
  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_controller == null) return null;

    final camera = _controller!.description;
    final sensorOrientation = camera.sensorOrientation;
    
    // Rotation logic
    final InputImageRotation rotation = InputImageRotationValue.fromRawValue(sensorOrientation) 
        ?? InputImageRotation.rotation0deg;

    final format = InputImageFormatValue.fromRawValue(image.format.raw) 
        ?? InputImageFormat.nv21;

    // Combine planes
    final plane = image.planes.first;
    
    // Note: This basic conversion works for NV21 (Android) and BGRA8888 (iOS).
    // Complex YUV conversions may require more code if using high-res.
    return InputImage.fromBytes(
      bytes: Uint8List.fromList(
        image.planes.fold<List<int>>([], (previous, plane) => previous..addAll(plane.bytes)),
      ),
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  @override
  void dispose() {
    _controller?.stopImageStream();
    _controller?.dispose();
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("ASL Translator (100 Words)")),
      body: Stack(
        children: [
          // 1. Camera Feed
          CameraPreview(_controller!),
          
          // 2. Detection Overlay
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "DETECTED SIGN",
                    style: TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _detectedWord,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
