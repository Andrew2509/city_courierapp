import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:city_courierapp/screens/home/tracking/tracking_detail_screen.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({Key? key}) : super(key: key);

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _controller;
  late Animation<double> _animation;
  
  // Gunakan Late agar bisa kita kontrol lifecycle-nya dengan lebih baik
  late MobileScannerController scannerController;
  bool _isScanned = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Pantau jika aplikasi di-minimize/resume
    
    scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.unrestricted,
      facing: CameraFacing.back,
      autoStart: true,
    );

    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  // Penting: Restart kamera jika aplikasi dibuka kembali dari background
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!scannerController.value.isInitialized) return;

    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      scannerController.stop();
    } else if (state == AppLifecycleState.resumed) {
      scannerController.start();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    scannerController.dispose();
    super.dispose();
  }

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (_isScanned) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? code = barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    debugPrint('=== BARCODE TERDETEKSI: $code ===');

    setState(() {
      _isScanned = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Mendapatkan data untuk resi: $code...'),
        duration: const Duration(milliseconds: 1000),
        backgroundColor: const Color(0xFFEC5B13),
      ),
    );

    try {
      if (!mounted) return;

      debugPrint('=== NAVIGASI KE TRACKING DETAIL ===');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => TrackingDetailScreen(trackingNumber: code),
        ),
      );
    } catch (e) {
      debugPrint('=== ERROR SAAT TRACKING: $e ===');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menghubungkan ke server: $e')),
        );
        setState(() => _isScanned = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFFEC5B13);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // SCANNER dengan Error Handler
          MobileScanner(
            controller: scannerController,
            onDetect: _handleBarcode,
            errorBuilder: (context, error, child) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.camera_alt_outlined, color: Colors.white54, size: 64),
                    const SizedBox(height: 16),
                    Text(
                      'Kamera bermasalah: ${error.errorCode}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => scannerController.start(),
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              );
            },
          ),
          
          _buildOverlay(context, primaryColor),
          
          // Header Overlay
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildRoundButton(Icons.arrow_back, () => Navigator.pop(context)),
                  const Text(
                    'Pindai Resi',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  _buildRoundButton(Icons.flashlight_on, () {
                    scannerController.toggleTorch();
                  }),
                ],
              ),
            ),
          ),

          // Action Controls Footer
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.only(bottom: 40, top: 40),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.9),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Arahkan kamera ke barcode resi',
                    style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildFooterAction(Icons.image_outlined, 'Galeri', () {}),
                      _buildMainScanButton(primaryColor),
                      _buildFooterAction(Icons.edit_note, 'Manual', () => Navigator.pop(context)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverlay(BuildContext context, Color primaryColor) {
    final width = MediaQuery.of(context).size.width * 0.75;
    final height = width; // SQUARE for QR Code

    return Stack(
      children: [
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withOpacity(0.6),
            BlendMode.srcOut,
          ),
          child: Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Colors.black,
                  backgroundBlendMode: BlendMode.dstOut,
                ),
              ),
              Center(
                child: Container(
                  width: width,
                  height: height,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24), // More rounded for QR
                  ),
                ),
              ),
            ],
          ),
        ),
        
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: width,
                height: height,
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
                      ),
                    ),
                    _buildCorner(0, 0, 1, 0, primaryColor), // TL
                    _buildCorner(0, 1, 1, 0, primaryColor), // TR
                    _buildCorner(1, 0, 0, 1, primaryColor), // BL
                    _buildCorner(1, 1, 0, 1, primaryColor), // BR
                    
                    AnimatedBuilder(
                      animation: _animation,
                      builder: (context, child) {
                        return Positioned(
                          top: _animation.value * (height - 4),
                          left: 10,
                          right: 10,
                          child: Container(
                            height: 2,
                            decoration: BoxDecoration(
                              color: primaryColor,
                              boxShadow: [
                                BoxShadow(
                                  color: primaryColor,
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'SCAN QR CODE RESI',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRoundButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
        ),
        child: Center(
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Widget _buildCorner(double? top, double? right, double? bottom, double? left, Color color) {
    return Positioned(
      top: top != null ? 0 : null,
      right: right != null ? 0 : null,
      bottom: bottom != null ? 0 : null,
      left: left != null ? 0 : null,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          border: Border(
            top: (top == 0) ? BorderSide(color: color, width: 4) : BorderSide.none,
            bottom: (bottom == 0) ? BorderSide(color: color, width: 4) : BorderSide.none,
            left: (left == 0) ? BorderSide(color: color, width: 4) : BorderSide.none,
            right: (right == 0) ? BorderSide(color: color, width: 4) : BorderSide.none,
          ),
          borderRadius: BorderRadius.only(
            topLeft: (top == 0 && left == 0) ? const Radius.circular(12) : Radius.zero,
            topRight: (top == 0 && right == 0) ? const Radius.circular(12) : Radius.zero,
            bottomLeft: (bottom == 0 && left == 0) ? const Radius.circular(12) : Radius.zero,
            bottomRight: (bottom == 0 && right == 0) ? const Radius.circular(12) : Radius.zero,
          ),
        ),
      ),
    );
  }

  Widget _buildFooterAction(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
            ),
            child: Center(child: Icon(icon, color: Colors.white70, size: 24)),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildMainScanButton(Color primaryColor) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: primaryColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.4),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Center(
        child: Icon(Icons.qr_code_scanner, color: Colors.white, size: 32),
      ),
    );
  }
}
