import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import '../widgets/daftar_kurir_components.dart';
import '../widgets/daftar_kurir_constants.dart';
import '../widgets/dashed_border.dart';
import '../daftar_kurir_data.dart';
import 'review_pendaftaran_screen.dart';

class FotoWajahScreen extends StatefulWidget {
  const FotoWajahScreen({super.key});

  @override
  State<FotoWajahScreen> createState() => _FotoWajahScreenState();
}

class _FotoWajahScreenState extends State<FotoWajahScreen> {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  File? _capturedImage;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      // Find the front camera
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: DaftarKurirColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Verifikasi Wajah',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: DaftarKurirColors.textDark,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress Indicator
            const StepProgressIndicator(
              currentStep: 4,
              totalSteps: 4,
            ),
            
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
                child: Column(
                  children: [
                    // Instructions
                    const Text(
                      'Posisikan wajah Anda di dalam lingkaran',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: DaftarKurirColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Pastikan wajah terlihat jelas dan tidak memakai kacamata hitam atau masker.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: DaftarKurirColors.textSub,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Camera Viewfinder Placeholder
                    SizedBox(
                      width: 256,
                      height: 256,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Camera Feed or Background
                          ClipOval(
                            child: SizedBox(
                              width: 256,
                              height: 256,
                              child: _isCameraInitialized && _cameraController != null
                                  ? FittedBox(
                                      fit: BoxFit.cover,
                                      child: SizedBox(
                                        width: _cameraController!.value.previewSize?.height ?? 1,
                                        height: _cameraController!.value.previewSize?.width ?? 1,
                                        child: CameraPreview(_cameraController!),
                                      ),
                                    )
                                  : Container(
                                      decoration: BoxDecoration(
                                        color: DaftarKurirColors.bgLight,
                                      ),
                                      child: Icon(
                                        Icons.face_rounded,
                                        size: 120,
                                        color: DaftarKurirColors.textMuted.withOpacity(0.5),
                                      ),
                                    ),
                            ),
                          ),
                          
                          // Circular Border Overlay
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 4,
                              ),
                            ),
                          ),
                          
                          // Dashed Circle Overlay
                          Positioned.fill(
                            child: DashedBorder(
                              color: DaftarKurirColors.primary.withOpacity(0.8),
                              strokeWidth: 2,
                              radius: 128,
                              dashPattern: const [8, 8],
                              child: const SizedBox(),
                            ),
                          ),
                          
                          // Corner brackets
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _ViewfinderBracketPainter(
                                color: DaftarKurirColors.primary,
                                strokeWidth: 4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Tips Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F4F6), // surface-container-low
                        border: Border.all(color: DaftarKurirColors.border),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.lightbulb,
                                color: DaftarKurirColors.primary,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Tips Foto Wajah',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: DaftarKurirColors.textDark,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildTipItem('Gunakan pencahayaan yang cukup.'),
                          const SizedBox(height: 8),
                          _buildTipItem('Lepas kacamata hitam atau masker.'),
                          const SizedBox(height: 8),
                          _buildTipItem('Posisikan wajah di tengah area.'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Bottom Action (Shutter Button)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 16, bottom: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: DaftarKurirColors.border),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    offset: const Offset(0, -4),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Center(
                child: GestureDetector(
                  onTap: () async {
                    if (_cameraController != null && _cameraController!.value.isInitialized) {
                      try {
                        final XFile picture = await _cameraController!.takePicture();
                        _capturedImage = File(picture.path);
                        context.read<DaftarKurirData>().photoPath = _capturedImage!.path;
                      } catch (e) {
                        debugPrint('Error taking selfie: $e');
                      }
                    }
                    if (context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ReviewPendaftaranScreen(),
                        ),
                      );
                    }
                  },
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFE6E8EA), // surface-container-high
                      border: Border.all(
                        color: DaftarKurirColors.border,
                        width: 4,
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: DaftarKurirColors.primary,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipItem(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2.0),
          child: Icon(
            Icons.check_circle_outline,
            color: DaftarKurirColors.primary,
            size: 16,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              color: DaftarKurirColors.textSub,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _ViewfinderBracketPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _ViewfinderBracketPainter({
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final double w = size.width;

    // Corner curves (matches the SVG in HTML: <path d="M 64 32 Q 32 32 32 64" /> etc. for a 256x256 view)
    // 64 is 1/4 of 256, 32 is 1/8 of 256
    
    final double c1 = w * (32 / 256); // 32
    final double c2 = w * (64 / 256); // 64
    final double c3 = w * (192 / 256); // 192
    final double c4 = w * (224 / 256); // 224

    // Top-left
    canvas.drawPath(
      Path()
        ..moveTo(c2, c1)
        ..quadraticBezierTo(c1, c1, c1, c2),
      paint,
    );
    // Top-right
    canvas.drawPath(
      Path()
        ..moveTo(c3, c1)
        ..quadraticBezierTo(c4, c1, c4, c2),
      paint,
    );
    // Bottom-left
    canvas.drawPath(
      Path()
        ..moveTo(c2, c4)
        ..quadraticBezierTo(c1, c4, c1, c3),
      paint,
    );
    // Bottom-right
    canvas.drawPath(
      Path()
        ..moveTo(c3, c4)
        ..quadraticBezierTo(c4, c4, c4, c3),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ViewfinderBracketPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
  }
}
