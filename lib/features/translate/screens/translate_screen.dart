import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:provider/provider.dart';
import '../../../services/sign_language_service.dart';

class TranslateScreen extends StatefulWidget {
  const TranslateScreen({super.key});

  @override
  State<TranslateScreen> createState() => _TranslateScreenState();
}

class _TranslateScreenState extends State<TranslateScreen> {
  int _selectedIndex = 0; // 0: Sign Mode, 1: Voice Mode
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  String _translationText = "Waiting for input...";
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    // Initialize logic for Sign Mode by default
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        // Use the front camera if available, otherwise the first one
        final camera = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
          orElse: () => cameras.first,
        );

        _cameraController = CameraController(
          camera,
          ResolutionPreset.medium,
          enableAudio: false,
        );

        await _cameraController!.initialize();
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
          // Start stream for inference
          _startInferenceStream();
        }
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  void _startInferenceStream() {
    if (_cameraController == null || !_cameraController!.value.isInitialized)
      return;

    int frameCount = 0;
    _cameraController!.startImageStream((CameraImage image) async {
      frameCount++;
      if (frameCount % 30 != 0) return;
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null || !mounted) return;
      final service = context.read<SignLanguageService>();
      final result = await service.processFrame(
        inputImage,
        cameraImage: image,
        sensorOrientation: _cameraController!.description.sensorOrientation,
      );
      if (mounted && result != null) {
        setState(() {
          _translationText = result;
        });
      }
    });
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_cameraController == null) return null;
    final sensorOrientation = _cameraController!.description.sensorOrientation;
    final rotation =
        InputImageRotationValue.fromRawValue(sensorOrientation) ??
        InputImageRotation.rotation0deg;
    final format =
        InputImageFormatValue.fromRawValue(image.format.raw) ??
        InputImageFormat.nv21;
    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: Uint8List.fromList(
        image.planes.fold<List<int>>([], (prev, p) => prev..addAll(p.bytes)),
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
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // Content Area
          Expanded(
            child: _selectedIndex == 0 ? _buildSignMode() : _buildVoiceMode(),
          ),

          // Bottom Controls
          Container(
            color: const Color(0xFF212121),
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(
                      value: 0,
                      label: Text('Sign'),
                      icon: Icon(Icons.back_hand),
                    ),
                    ButtonSegment(
                      value: 1,
                      label: Text('Voice'),
                      icon: Icon(Icons.mic),
                    ),
                  ],
                  selected: {_selectedIndex},
                  onSelectionChanged: (Set<int> newSelection) {
                    setState(() {
                      _selectedIndex = newSelection.first;
                      if (_selectedIndex == 0) {
                        _initializeCamera();
                      } else {
                        // Dispose camera when switching to Voice to save resources
                        _cameraController?.dispose();
                        _isCameraInitialized = false;
                      }
                    });
                  },
                  style: ButtonStyle(
                    backgroundColor: MaterialStateProperty.resolveWith<Color>((
                      Set<MaterialState> states,
                    ) {
                      if (states.contains(MaterialState.selected)) {
                        return const Color(0xFF00897B);
                      }
                      return Colors.grey[800]!;
                    }),
                    foregroundColor: MaterialStateProperty.resolveWith<Color>((
                      Set<MaterialState> states,
                    ) {
                      if (states.contains(MaterialState.selected)) {
                        return Colors.white;
                      }
                      return Colors.grey;
                    }),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignMode() {
    if (!_isCameraInitialized) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              "Initializing Camera...",
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        // Camera Preview
        SizedBox.expand(child: CameraPreview(_cameraController!)),

        // Output Overlay
        Positioned(
          bottom: 20,
          left: 16,
          right: 16,
          child: Card(
            color: Colors.white.withOpacity(0.9),
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _translationText,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.volume_up,
                          color: Color(0xFF00897B),
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Reading text aloud...'),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVoiceMode() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                _isListening = !_isListening;
                _translationText = _isListening
                    ? "Listening..."
                    : "Speech-to-Text Result mockup.";
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 120,
              width: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isListening
                    ? Colors.redAccent
                    : const Color(0xFF00897B),
                boxShadow: [
                  BoxShadow(
                    color:
                        (_isListening
                                ? Colors.redAccent
                                : const Color(0xFF00897B))
                            .withOpacity(0.5),
                    blurRadius: 30,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: Icon(
                _isListening ? Icons.stop : Icons.mic,
                size: 60,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 48),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              _isListening ? "Listening..." : "Tap mic to speak",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[400], fontSize: 18),
            ),
          ),
          if (!_isListening && _translationText != "Waiting for input...")
            Padding(
              padding: const EdgeInsets.only(top: 24.0),
              child: Text(
                _translationText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
