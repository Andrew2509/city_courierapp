import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:city_courierapp/core/config/app_colors.dart';
import 'package:city_courierapp/core/config/app_typography.dart';

class DriverPhotoCaptureScreen extends StatefulWidget {
  final Map<String, dynamic> order;

  const DriverPhotoCaptureScreen({
    super.key,
    required this.order,
  });

  @override
  State<DriverPhotoCaptureScreen> createState() => _DriverPhotoCaptureScreenState();
}

class _DriverPhotoCaptureScreenState extends State<DriverPhotoCaptureScreen> {
  CameraController? _controller;
  bool _isCameraInitialized = false;
  bool _isFlashOn = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;
      
      _controller = CameraController(
        cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      
      await _controller!.initialize();
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
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_controller!.value.isTakingPicture) return;
    
    try {
      final XFile file = await _controller!.takePicture();
      if (_isFlashOn) {
        await _controller!.setFlashMode(FlashMode.off);
      }
      if (mounted) {
        Navigator.pop(context, file.path);
      }
    } catch (e) {
      debugPrint('Error taking picture: $e');
    }
  }

  Future<void> _toggleFlash() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    
    try {
      if (_isFlashOn) {
        await _controller!.setFlashMode(FlashMode.off);
        setState(() { _isFlashOn = false; });
      } else {
        await _controller!.setFlashMode(FlashMode.torch);
        setState(() { _isFlashOn = true; });
      }
    } catch (e) {
      debugPrint('Error toggling flash: $e');
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE2E8F0),
      body: SafeArea(
        bottom: false,
        child: Container(
          color: const Color(0xFFFAFAFA),
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildCameraContainer(context),
                      _buildTipsCard(),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFF1F5F9)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
          ),
          Text(
            'Foto Bukti Pengiriman',
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1A1A1A),
            ),
          ),
          const Icon(Icons.headset_mic_outlined, color: AppColors.primaryOrange),
        ],
      ),
    );
  }

  Widget _buildCameraContainer(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      height: 480,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          // Camera View
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_isCameraInitialized && _controller != null)
                  CameraPreview(_controller!)
                else
                  const Center(child: CircularProgressIndicator(color: AppColors.primaryOrange)),
                Align(
                alignment: Alignment.topLeft,
                child: Container(
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.camera_alt_outlined,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Pastikan foto jelas dan paket terlihat\ndengan baik',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                ),
              ],
            ),
          ),
          // Camera Controls
          Container(
            height: 120,
            color: const Color(0xFF0F0F0F),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildControlBtn(
                  icon: Icons.close,
                  label: 'Batal',
                  onTap: () => Navigator.pop(context),
                ),
                _buildShutterBtn(context),
                _buildControlBtn(
                  icon: _isFlashOn ? Icons.flash_on : Icons.flash_off,
                  label: 'Lampu',
                  onTap: _toggleFlash,
                  color: _isFlashOn ? AppColors.primaryOrange : Colors.white,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlBtn({required IconData icon, required String label, required VoidCallback onTap, Color color = Colors.white}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShutterBtn(BuildContext context) {
    return GestureDetector(
      onTap: _takePicture,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
        ),
        padding: const EdgeInsets.all(4),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  Widget _buildTipsCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tips Foto yang Baik',
            style: AppTypography.bodySmall.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 12),
          _buildTipItem('Ambil foto paket dengan jelas'),
          const SizedBox(height: 10),
          _buildTipItem('Pastikan alamat dan penerima terlihat (jika memungkinkan)'),
          const SizedBox(height: 10),
          _buildTipItem('Foto di tempat terang'),
        ],
      ),
    );
  }

  Widget _buildTipItem(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF64748B),
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
