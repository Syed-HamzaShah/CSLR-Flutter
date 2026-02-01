import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../services/sign_language_service.dart';

class SignInputScreen extends StatefulWidget {
  const SignInputScreen({super.key});

  @override
  State<SignInputScreen> createState() => _SignInputScreenState();
}

class _SignInputScreenState extends State<SignInputScreen> {
  CameraController? _cameraController;
  String _currentPrediction = "";
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        final camera = cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.front,
            orElse: () => cameras.first);

        _cameraController = CameraController(
          camera,
          ResolutionPreset.medium,
          enableAudio: false,
        );

        await _cameraController!.initialize();
        if (mounted) {
          setState(() {});
          _startPredictionStream();
        }
      }
    } catch (e) {
      debugPrint("Camera error: $e");
    }
  }

  void _startPredictionStream() {
     if (_cameraController == null) return;
     
     int frameCounter = 0;
     _cameraController!.startImageStream((CameraImage image) {
       // Throttle to every 20 frames to simulate realistic inference timing
       frameCounter++;
       if (frameCounter % 20 != 0) return;

       if (mounted) {
         final service = context.read<SignLanguageService>();
         final result = service.runInference(image);
         setState(() {
           _currentPrediction = result;
         });
       }
     });
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  void _confirmAndSend() {
    context.pop(_currentPrediction);
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Full Screen Camera
          SizedBox.expand(
            child: CameraPreview(_cameraController!),
          ),

          // 2. Top Overlay (Reply Context)
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.reply, color: Colors.white70),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Replying to: Hello! How are you?", // Mock context
                      style: TextStyle(color: Colors.white, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Close Button
          Positioned(
            top: 50,
            right: 10,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => context.pop(),
            ),
          ),

          // 4. Bottom Overlay (Live Caption & Send)
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Live Caption Box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        spreadRadius: 2
                      )
                    ]
                  ),
                  child: Column(
                    children: [
                      const Text(
                        "DETECTED TEXT",
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 10,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _currentPrediction.isEmpty ? "..." : _currentPrediction,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                
                // Send/Confirm Button
                SizedBox(
                  width: 70,
                  height: 70,
                  child: FloatingActionButton(
                    onPressed: _currentPrediction.isNotEmpty ? _confirmAndSend : null,
                    backgroundColor: _currentPrediction.isNotEmpty 
                        ? const Color(0xFF00897B) // Teal
                        : Colors.grey, 
                    shape: const CircleBorder(),
                    child: const Icon(Icons.check, size: 32, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
