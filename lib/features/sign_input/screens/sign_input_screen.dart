import 'dart:io';
import 'dart:typed_data'; // Needed for Uint8List
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
      ResolutionPreset.low, // Lower resolution for faster processing
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );

    try {
      await _controller!.initialize();
      if (!mounted) return;

      // Start Stream
      _controller!.startImageStream((CameraImage image) async {
        if (_isProcessingFrame) return;
        _isProcessingFrame = true;

        try {
          final inputImage = _inputImageFromCameraImage(image);
          if (inputImage != null) {
            final result = await _service.processFrame(
              inputImage,
              cameraImage: image,
              sensorOrientation: _controller!.description.sensorOrientation,
            );

            if (result != null) {
              setState(() {
                _detectedWord = result;
              });
            }
          }
        } catch (e) {
          debugPrint("Error processing frame: $e");
        } finally {
          _isProcessingFrame = false;
        }
      });

      setState(() {});
    } catch (e) {
      debugPrint("Camera initialization error: $e");
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_controller == null) return null;

    final camera = _controller!.description;
    final sensorOrientation = camera.sensorOrientation;

    // Rotation
    final InputImageRotation rotation =
        InputImageRotationValue.fromRawValue(sensorOrientation) ??
        InputImageRotation.rotation0deg;

    // Format
    final InputImageFormat format =
        InputImageFormatValue.fromRawValue(image.format.raw) ??
        InputImageFormat.nv21;

    // Bytes
    // For NV21 (Android), plane[0] is Y, plane[1] is VU interlaced (or similar).
    // InputImage.fromBytes handles this if we pass all bytes.
    final allBytes = WriteBuffer();
    for (final plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    // Metadata
    final metadata = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: format,
      bytesPerRow: image.planes[0].bytesPerRow, 
    );

    return InputImage.fromBytes(bytes: bytes, metadata: metadata);
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
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("ASL Translator")),
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera Preview
          CameraPreview(_controller!),

          // Overlay
          Positioned(
            bottom: 50,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "DETECTED SIGN",
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _detectedWord,
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
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
