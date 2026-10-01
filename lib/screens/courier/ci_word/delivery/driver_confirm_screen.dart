import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:ui';
import 'package:image_picker/image_picker.dart';
import 'package:city_courierapp/core/config/app_colors.dart';
import 'package:city_courierapp/core/config/app_typography.dart';
import 'package:city_courierapp/screens/courier/ci_word/widgets/driver_bottom_navigation.dart';
import 'package:city_courierapp/screens/courier/ci_word/delivery/driver_complete_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/home/driver_home_screen.dart';
import 'package:city_courierapp/services/courier/courier_order_service.dart';
import 'package:city_courierapp/screens/courier/ci_word/shipment/driver_shipment_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/earnings/driver_earnings_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/profile/driver_profile_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/delivery/driver_photo_capture_screen.dart';

class DriverConfirmScreen extends StatefulWidget {
  final Map<String, dynamic> order;

  const DriverConfirmScreen({
    super.key,
    required this.order,
  });

  @override
  State<DriverConfirmScreen> createState() => _DriverConfirmScreenState();
}

class _DriverConfirmScreenState extends State<DriverConfirmScreen> {
  bool _isLoading = false;
  File? _proofImage;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source, imageQuality: 70);
      if (pickedFile != null) {
        setState(() {
          _proofImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengambil gambar: $e')),
        );
      }
    }
  }

  Future<void> _openCustomCamera() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DriverPhotoCaptureScreen(order: widget.order),
      ),
    );
    
    if (result != null && result is String) {
      setState(() {
        _proofImage = File(result);
      });
    }
  }

  void _onConfirmPressed() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await CourierOrderService.updateOrderStatus(
        orderId: widget.order['id'].toString(),
        status: 'delivered',
        photoPath: _proofImage?.path,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (result['success'] == true) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DriverCompleteScreen(order: result['data'] ?? widget.order),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Gagal mengkonfirmasi pengiriman'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Terjadi kesalahan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // Show confirmation dialog
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Konfirmasi'),
            content: const Text('Apakah Anda yakin ingin kembali? Konfirmasi penerimaan belum selesai.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Tidak'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx); // close dialog
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const DriverShipmentScreen()),
                  );
                },
                child: const Text('Ya, Kembali'),
              ),
            ],
          ),
        );
      },
      child: Scaffold(
      backgroundColor: const Color(0xFFE2E8F0),
      body: SafeArea(
        bottom: false,
        child: Container(
          color: const Color(0xFFFAFAFA),
          child: Stack(
            children: [
              Column(
                children: [
                  _buildHeader(context),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            child: Column(
                              children: [
                                _buildOrderInfoCard(),
                                const SizedBox(height: 16),
                                _buildConfirmCard(),
                                const SizedBox(height: 120),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              // Bottom Action Fixed
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFFFAFAFA).withOpacity(0.0),
                        const Color(0xFFFAFAFA),
                        const Color(0xFFFAFAFA),
                      ],
                      stops: const [0.0, 0.2, 1.0],
                    ),
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _onConfirmPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryOrange,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Konfirmasi Penerimaan',
                            style: AppTypography.bodyMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: DriverBottomNavigation(
        currentIndex: 1, // Shipment tab is selected
        onTap: (index) {
          if (index == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const DriverHomeScreen()),
            );
          } else if (index == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const DriverShipmentScreen()),
            );
          } else if (index == 2) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const DriverEarningsScreen()),
            );
          } else if (index == 3) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const DriverProfileScreen()),
            );
          }
        },
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
          const Icon(Icons.arrow_back, color: Color(0xFFE2E8F0)), // Disabled back button
          Text(
            'Konfirmasi Penerima',
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

  Widget _buildBannerBox() {
    return Container(
      width: double.infinity,
      height: 160,
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF4b5563), Color(0xFF374151)],
        ),
      ),
      child: Center(
        child: Text(
          'Ilustrasi Kurir & Penerima',
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildOrderInfoCard() {
    final String trackingNumber = widget.order['tracking_number'] ?? widget.order['order_number'] ?? widget.order['id']?.toString() ?? '-';
    
    // Read from backend flat fields with nested fallback
    final pickupLoc = widget.order['pickup_location'] ?? {};
    final dropoffLoc = widget.order['dropoff_location'] ?? {};
    
    final pickupName = pickupLoc['name'] ?? widget.order['pickup_name'] ?? widget.order['sender_name'] ?? 'Lokasi Penjemputan';
    final pickupAddress = widget.order['pickup_address'] ?? pickupLoc['address'] ?? '-';
    
    final dropoffName = dropoffLoc['name'] ?? widget.order['dropoff_name'] ?? widget.order['receiver_name'] ?? 'Lokasi Tujuan';
    final dropoffAddress = widget.order['dropoff_address'] ?? widget.order['delivery_address'] ?? dropoffLoc['address'] ?? '-';

    return Container(
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
            'Order ID: #$trackingNumber',
            style: AppTypography.bodySmall.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.primaryOrange,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    // Pickup
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          children: [
                            Container(
                              width: 18,
                              height: 18,
                              decoration: const BoxDecoration(
                                color: AppColors.primaryOrange,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.arrow_upward, color: Colors.white, size: 12),
                            ),
                            Container(
                              width: 1,
                              height: 40,
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              color: const Color(0xFFCBD5E1),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pickupName,
                                style: AppTypography.bodySmall.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF1A1A1A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                pickupAddress,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    // Dropoff
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          decoration: const BoxDecoration(
                            color: Color(0xFF22C55E),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.location_on, color: Colors.white, size: 12),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                dropoffName,
                                style: AppTypography.bodySmall.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF1A1A1A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                dropoffAddress,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 80,
                color: const Color(0xFFE2E8F0),
                margin: const EdgeInsets.symmetric(horizontal: 16),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Estimasi', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
                  const SizedBox(height: 4),
                  Text('11:30 - 12:00', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF1A1A1A))),
                  const SizedBox(height: 16),
                  Text('Harga', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
                  const SizedBox(height: 4),
                  Text('Rp ${widget.order['price'] ?? widget.order['total_amount'] ?? '25.000'}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF22C55E))),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'COD',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: const Color(0xFF475569)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmCard() {
    final dropoffLoc = widget.order['dropoff_location'] ?? {};
    final dropoffName = dropoffLoc['name'] ?? widget.order['dropoff_name'] ?? widget.order['receiver_name'] ?? 'Penerima';
    final now = DateTime.now();
    final dateString = DateFormat('dd MMM yyyy, HH:mm').format(now);

    return Container(
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
            'Konfirmasi Penerimaan',
            style: AppTypography.bodySmall.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pastikan paket telah diterima oleh penerima.',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 20),
          
          // Info Rows
          _buildInfoRow('Nama Penerima', dropoffName),
          _buildInfoRow('Tanggal & Waktu', dateString, noBorder: true),
          
          const SizedBox(height: 16),
          
          // Photos
          Row(
            children: [
              _buildPhotoThumbnail(),
              const SizedBox(width: 12),
              _buildAddPhotoBtn(Icons.camera_alt_outlined, 'Kamera', _openCustomCamera),
              const SizedBox(width: 12),
              _buildAddPhotoBtn(Icons.photo_library_outlined, 'Galeri', () => _pickImage(ImageSource.gallery)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool noBorder = false}) {
    return Container(
      padding: const EdgeInsets.only(bottom: 12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: noBorder
          ? null
          : const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
            ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xFF64748B)),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFF1A1A1A)),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoThumbnail() {
    return Expanded(
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF915931),
            borderRadius: BorderRadius.circular(12),
            image: _proofImage != null
                ? DecorationImage(
                    image: FileImage(_proofImage!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          clipBehavior: Clip.hardEdge,
          child: Stack(
            children: [
              if (_proofImage == null)
                const Center(
                  child: Icon(Icons.inventory_2_outlined, color: Colors.white, size: 24),
                ),
              if (_proofImage != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _proofImage = null;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: AppColors.primaryOrange,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white, size: 10),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddPhotoBtn(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: AspectRatio(
        aspectRatio: 1,
        child: CustomPaint(
          painter: _DashedRectPainter(color: const Color(0xFFCBD5E1), strokeWidth: 1.5, radius: 12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: const Color(0xFF64748B), size: 20),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double radius;

  _DashedRectPainter({required this.color, required this.strokeWidth, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path();
    final rrect = RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height), Radius.circular(radius));
    path.addRRect(rrect);

    final Path dashPath = Path();
    const dashWidth = 5.0;
    const dashSpace = 3.0;
    var distance = 0.0;
    
    for (PathMetric pathMetric in path.computeMetrics()) {
      while (distance < pathMetric.length) {
        dashPath.addPath(
          pathMetric.extractPath(distance, distance + dashWidth),
          Offset.zero,
        );
        distance += dashWidth;
        distance += dashSpace;
      }
      distance = 0.0;
    }

    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
