import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import '../widgets/daftar_kurir_components.dart';
import '../widgets/daftar_kurir_constants.dart';
import '../daftar_kurir_data.dart';

class VerifikasiKtpScreen extends StatefulWidget {
  const VerifikasiKtpScreen({super.key});

  @override
  State<VerifikasiKtpScreen> createState() => _VerifikasiKtpScreenState();
}

class _VerifikasiKtpScreenState extends State<VerifikasiKtpScreen> {
  File? _imageFile;
  CameraController? _cameraController;
  bool _isCameraInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      // Find the rear camera
      CameraDescription? rearCamera;
      for (var camera in cameras) {
        if (camera.lensDirection == CameraLensDirection.back) {
          rearCamera = camera;
          break;
        }
      }
      rearCamera ??= cameras.first;

      _cameraController = CameraController(
        rearCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      debugPrint("Error initializing camera: $e");
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    
    if (_cameraController!.value.isTakingPicture) {
      return;
    }

    try {
      final XFile picture = await _cameraController!.takePicture();
      setState(() {
        _imageFile = File(picture.path);
      });
    } catch (e) {
      debugPrint("Error taking picture: $e");
    }
  }

  void _retakePicture() {
    setState(() {
      _imageFile = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ScreenLayout(
      title: 'Verifikasi KTP',
      currentStep: 4,
      totalSteps: 4,
      transparentBottomAction: true,
      bottomAction: _imageFile == null
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: _takePicture,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: DaftarKurirColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF111827).withOpacity(0.1),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white, width: 2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Ambil Foto',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: DaftarKurirColors.textDark,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PrimaryButton(
                  text: 'Simpan',
                  onPressed: () {
                    if (_imageFile != null) {
                      context.read<DaftarKurirData>().idCardPath = _imageFile!.path;
                    }
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(height: 12),
                OutlineButton(
                  text: 'Foto Ulang',
                  onPressed: _retakePicture,
                ),
                const SizedBox(height: 24),
              ],
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          // Instructions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: DaftarKurirColors.border.withOpacity(0.5)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Column(
              children: const [
                Text(
                  'Posisikan KTP di dalam kotak',
                  style: TextStyle(
                    fontSize: 16,
                    color: DaftarKurirColors.textDark,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 4),
                Text(
                  'Pastikan tulisan terbaca jelas dan tidak ada pantulan cahaya',
                  style: TextStyle(
                    fontSize: 14,
                    color: DaftarKurirColors.textMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Viewfinder Frame
          Center(
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF2D3133), // bg-inverse-surface
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Camera Preview or Picked Image
                      if (_imageFile == null)
                        if (_isCameraInitialized && _cameraController != null)
                          SizedBox.expand(
                            child: FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width: _cameraController!.value.previewSize!.height,
                                height: _cameraController!.value.previewSize!.width,
                                child: CameraPreview(_cameraController!),
                              ),
                            ),
                          )
                        else
                          const Center(
                            child: CircularProgressIndicator(color: DaftarKurirColors.primary),
                          )
                      else
                        SizedBox.expand(
                          child: Image.file(
                            _imageFile!,
                            fit: BoxFit.cover,
                          ),
                        ),

                      // Overlay and guides (only show when camera is active, hide when picture is taken)
                      if (_imageFile == null) ...[
                        // Corner Markers and Dashed Border effect
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: DaftarKurirColors.primary.withOpacity(0.8),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Corner Markers
                        Positioned(
                          top: 16, left: 16,
                          child: _buildCorner(isTop: true, isLeft: true),
                        ),
                        Positioned(
                          top: 16, right: 16,
                          child: _buildCorner(isTop: true, isLeft: false),
                        ),
                        Positioned(
                          bottom: 16, left: 16,
                          child: _buildCorner(isTop: false, isLeft: true),
                        ),
                        Positioned(
                          bottom: 16, right: 16,
                          child: _buildCorner(isTop: false, isLeft: false),
                        ),
                        
                        // Example Icon
                        const Icon(
                          Icons.badge_outlined,
                          size: 80,
                          color: Colors.white30,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          
          // Tips
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: DaftarKurirColors.bgLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: DaftarKurirColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.lightbulb_outline_rounded,
                    color: DaftarKurirColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tips Foto KTP:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: DaftarKurirColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildBulletPoint('Gunakan pencahayaan yang cukup'),
                      const SizedBox(height: 4),
                      _buildBulletPoint('Hindari bayangan pada kartu'),
                      const SizedBox(height: 4),
                      _buildBulletPoint('Pastikan seluruh bagian KTP masuk area'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildCorner({required bool isTop, required bool isLeft}) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        border: Border(
          top: isTop ? const BorderSide(color: DaftarKurirColors.primary, width: 4) : BorderSide.none,
          bottom: !isTop ? const BorderSide(color: DaftarKurirColors.primary, width: 4) : BorderSide.none,
          left: isLeft ? const BorderSide(color: DaftarKurirColors.primary, width: 4) : BorderSide.none,
          right: !isLeft ? const BorderSide(color: DaftarKurirColors.primary, width: 4) : BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 6, right: 8),
          child: CircleAvatar(
            radius: 3,
            backgroundColor: DaftarKurirColors.textMuted,
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              color: DaftarKurirColors.textMuted,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
