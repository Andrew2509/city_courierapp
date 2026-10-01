import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:city_courierapp/core/config/app_colors.dart';
import 'package:city_courierapp/core/config/app_typography.dart';
import 'package:city_courierapp/screens/courier/ci_word/delivery/driver_photo_capture_screen.dart';
import 'package:city_courierapp/services/courier/courier_order_service.dart';

class DriverDeliveryConfirmationScreen extends StatefulWidget {
  final Map<String, dynamic> order;

  const DriverDeliveryConfirmationScreen({super.key, required this.order});

  @override
  State<DriverDeliveryConfirmationScreen> createState() =>
      _DriverDeliveryConfirmationScreenState();
}

class _DriverDeliveryConfirmationScreenState
    extends State<DriverDeliveryConfirmationScreen> {
  bool _isCompleting = false;
  bool _hasPhoto = false;
  String? _photoPath;

  // Verification toggles
  bool _isReceiverVerified = false;
  bool _isPackageHandedOver = false;

  // Order detail from passed data or mock
  late Map<String, dynamic> _orderDetail;

  @override
  void initState() {
    super.initState();
    _orderDetail = {
      'orderNumber': widget.order['tracking_number'] ?? widget.order['order_number'] ?? widget.order['id']?.toString() ?? 'CC-20260103-001',
      'sender': {
        'name': widget.order['sender_name'] ?? 'Budi Santoso',
        'phone': widget.order['sender_phone'] ?? '+62 812-3456-7890',
        'address': widget.order['pickup_address'] ?? 'Alamat Pengirim',
      },
      'receiver': {
        'name': widget.order['receiver_name'] ?? 'Siti Aminah',
        'phone': widget.order['receiver_phone'] ?? '+62 813-9876-5432',
        'address': widget.order['dropoff_address'] ?? 'Alamat Penerima',
      },
      'package': {
        'name': widget.order['item_type'] ?? 'Paket',
        'quantity': 1,
        'weight': '${widget.order['weight'] ?? "0"} kg',
        'dimensions': widget.order['dimensions'] ?? '30x21x2 cm',
      },
      'instructions': widget.order['notes'] ?? 'Tanpa instruksi khusus.',
    };
  }

  bool get _canComplete =>
      _hasPhoto && _isReceiverVerified && _isPackageHandedOver;

  void _takePhoto() async {
    String? capturedPath;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DriverPhotoCaptureScreen(
          order: widget.order,
        ),
      ),
    );

    if (result == true && capturedPath != null) {
      setState(() {
        _hasPhoto = true;
        _photoPath = capturedPath;
      });
    }
  }

  Future<void> _callPhone(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[\s\-]'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _reportIssue() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Fitur lapor masalah akan segera hadir!'),
        backgroundColor: AppColors.warningColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _completeDelivery() async {
    if (!_canComplete) return;

    setState(() {
      _isCompleting = true;
    });

    try {
      final result = await CourierOrderService.updateOrderStatus(
        orderId: widget.order['id'].toString(),
        status: 'delivered',
        photoPath: _photoPath,
      );

      if (mounted) {
        setState(() => _isCompleting = false);
        if (result['success'] == true) {
          Navigator.pop(context, _photoPath ?? 'completed');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? 'Gagal menyelesaikan pengiriman')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCompleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back, size: 24, color: AppColors.textPrimary),
        ),
        title: Text(
          'Delivery Confirmation',
          style: AppTypography.bodyLarge.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Banner
            _buildStatusBanner(),
            const SizedBox(height: 18),

            // Penerima Section
            _buildReceiverSection(),
            const SizedBox(height: 16),

            // Verifikasi Penerima
            _buildVerificationSection(),
            const SizedBox(height: 16),

            // Bukti Pengantaran (Photo)
            _buildPhotoSection(),
            const SizedBox(height: 16),

            // Detail Barang
            _buildPackageSection(),
            const SizedBox(height: 16),

            // Instruksi Khusus
            _buildInstructionsSection(),

            const SizedBox(height: 120),
          ],
        ),
      ),
      bottomSheet: _buildBottomActions(),
    );
  }

  Widget _buildStatusBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primaryOrange,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              color: AppColors.textWhite,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.local_shipping,
              color: AppColors.primaryOrange,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tiba di Lokasi Penerima',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textWhite,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'No. ${_orderDetail['orderNumber']}',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textWhite.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiverSection() {
    final receiver = _orderDetail['receiver'];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.backgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.dashboardCardBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.person,
                  color: AppColors.primaryOrange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Penerima',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      receiver['name'],
                      style: AppTypography.bodyLarge.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _callPhone(receiver['phone']),
                icon: const Icon(Icons.phone, size: 16),
                label: const Text('Hubungi'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryOrange,
                  side: BorderSide(color: AppColors.primaryOrange),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.location_on, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  receiver['address'],
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textPrimary.withValues(alpha: 0.8),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.dashboardCardBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Verifikasi Penyerahan',
            style: AppTypography.bodyLarge.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          _buildToggleItem(
            'Identitas penerima sudah dikonfirmasi',
            _isReceiverVerified,
            (val) => setState(() => _isReceiverVerified = val),
          ),
          _buildToggleItem(
            'Paket sudah diserahkan ke penerima',
            _isPackageHandedOver,
            (val) => setState(() => _isPackageHandedOver = val),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleItem(String title, bool value, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: value
                  ? AppColors.successColor
                  : AppColors.dashboardCardBorder,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check,
              color: AppColors.textWhite,
              size: 14,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: AppTypography.bodyMedium)),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primaryOrange,
            inactiveTrackColor: AppColors.dashboardCardBorder,
            inactiveThumbColor: AppColors.textWhite,
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.dashboardCardBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bukti Pengantaran',
            style: AppTypography.bodyLarge.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Ambil foto paket bersama penerima',
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          if (_hasPhoto && _photoPath != null)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(
                    File(_photoPath!),
                    width: double.infinity,
                    height: 160,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.successColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: AppColors.textWhite,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Foto Berhasil',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textWhite,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: _takePhoto,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.textPrimary.withValues(alpha: 0.2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.refresh,
                            size: 14,
                            color: AppColors.primaryOrange,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Ganti',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.primaryOrange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            OutlinedButton.icon(
              onPressed: _takePhoto,
              icon: Icon(
                Icons.camera_alt_outlined,
                color: AppColors.primaryOrange,
              ),
              label: Text(
                'Ambil Foto Bukti',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.primaryOrange,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: AppColors.primaryOrange),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                minimumSize: const Size(double.infinity, 52),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPackageSection() {
    final package = _orderDetail['package'];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.backgroundColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${package['quantity']}x ${package['name']}',
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Berat: ${package['weight']} • ${package['dimensions']}',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryOrange.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primaryOrange.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: AppColors.primaryOrange, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Instruksi Khusus',
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryOrange,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _orderDetail['instructions'],
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textPrimary.withValues(alpha: 0.8),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: AppColors.backgroundColor,
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Secondary buttons row
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _callPhone(_orderDetail['receiver']['phone']),
                  icon: const Icon(Icons.phone, size: 18),
                  label: Text(
                    'Hubungi Penerima',
                    style: AppTypography.caption.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(
                      color: AppColors.dashboardCardBorder,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _reportIssue,
                  icon: const Icon(Icons.warning_amber_outlined, size: 18),
                  label: Text(
                    'Laporkan Masalah',
                    style: AppTypography.caption.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(
                      color: AppColors.dashboardCardBorder,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Completion hint
          if (!_canComplete)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Lengkapi verifikasi dan foto untuk melanjutkan',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          // Main action button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _canComplete ? _completeDelivery : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                disabledBackgroundColor: AppColors.dashboardCardBorder,
                foregroundColor: AppColors.textWhite,
                elevation: _canComplete ? 4 : 0,
                shadowColor: AppColors.primaryOrange.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isCompleting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.textWhite,
                        ),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_canComplete)
                          const Icon(Icons.check_circle_outline, size: 20),
                        if (_canComplete) const SizedBox(width: 8),
                        Text(
                          'Selesaikan Pengiriman',
                          style: AppTypography.bodyLarge.copyWith(
                            color: _canComplete
                                ? AppColors.textWhite
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
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
