import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:city_courierapp/core/config/app_typography.dart';
import 'package:city_courierapp/core/config/app_colors.dart';
import 'package:city_courierapp/screens/courier/ci_word/delivery/driver_delivery_confirmation_screen.dart';

class DriverDeliveryInProgressScreen extends StatefulWidget {
  final Map<String, dynamic> order;

  const DriverDeliveryInProgressScreen({super.key, required this.order});

  @override
  State<DriverDeliveryInProgressScreen> createState() =>
      _DriverDeliveryInProgressScreenState();
}

class _DriverDeliveryInProgressScreenState
    extends State<DriverDeliveryInProgressScreen> {
  bool _isArriving = false;

  // Mock order detail data
  final Map<String, dynamic> _orderDetail = {
    'status': 'Dalam Perjalanan',
    'eta': '14:45 WIB',
    'sender': {
      'name': 'Budi Santoso',
      'phone': '+62 812-3456-7890',
      'address':
          'Jl. Jend. Sudirman No. 123, RT.05/RW.02, Karet Tengsin, Tanah Abang, Jakarta Pusat, 10220',
    },
    'receiver': {
      'name': 'Siti Aminah',
      'phone': '+62 813-9876-5432',
      'address':
          'Komplek Griya Indah, Blok C4 No. 15, Jl. Raya Pasar Minggu, Pejaten Timur, Pasar Minggu, Jakarta Selatan, 12510',
    },
    'package': {
      'name': 'Paket Dokumen Penting',
      'quantity': 1,
      'weight': '0.5 kg',
      'dimensions': '30x21x2 cm',
    },
    'instructions':
        'Tolong ketuk pintu pagar, jangan dibunyikan bel. Letakkan di teras jika tidak ada orang.',
  };

  Future<void> _openWhatsApp(String phoneNumber) async {
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[\s\-\+]'), '');
    // Format for WhatsApp: remove leading 0 and add country code if needed
    String waNumber = cleanNumber;
    if (waNumber.startsWith('0')) {
      waNumber = '62${waNumber.substring(1)}';
    } else if (!waNumber.startsWith('62')) {
      waNumber = '62$waNumber';
    }
    final uri = Uri.parse('https://wa.me/$waNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _arriveAtLocation() async {
    setState(() {
      _isArriving = true;
    });

    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) =>
              DriverDeliveryConfirmationScreen(order: widget.order),
        ),
      );
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
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
        ),
        title: Text(
          'Pengiriman Dalam Proses',
          style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Section
            _buildStatusSection(),

            const Divider(height: 1, color: Color(0xFFE0E0E0)),
            Divider(height: 1, color: AppColors.dashboardCardBorder),

            // Pengirim Section
            _buildContactSection(
              'Pengirim',
              _orderDetail['sender']['name'],
              _orderDetail['sender']['phone'],
              _orderDetail['sender']['address'],
            ),

            const Divider(height: 1, color: AppColors.dashboardCardBorder),

            // Penerima Section
            _buildContactSection(
              'Penerima',
              _orderDetail['receiver']['name'],
              _orderDetail['receiver']['phone'],
              _orderDetail['receiver']['address'],
            ),

            const Divider(height: 1, color: AppColors.dashboardCardBorder),

            // Detail Barang Section
            _buildPackageSection(),

            const Divider(height: 1, color: AppColors.dashboardCardBorder),

            // Instruksi Khusus Section
            _buildInstructionsSection(),

            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomButton(),
    );
  }

  Widget _buildStatusSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(
                0xFF2196F3,
              ).withValues(alpha: 0.1), // AppColors.primaryBlue
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.local_shipping,
              color: AppColors.primaryBlue, // AppColors.primaryBlue
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _orderDetail['status'],
                style: AppTypography.bodyLarge.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Estimasi Tiba: ${_orderDetail['eta']}',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary, // AppColors.textSecondary
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContactSection(
    String title,
    String name,
    String phone,
    String address,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          // Name row with WhatsApp button
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.person_outline,
                size: 20,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _openWhatsApp(phone),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Color(0xFF25D366),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: FaIcon(
                      FontAwesomeIcons.whatsapp,
                      color: AppColors.textWhite,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Phone row
          Row(
            children: [
              Icon(
                Icons.phone_outlined,
                size: 20,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 12),
              Text(phone, style: AppTypography.bodyMedium),
            ],
          ),
          const SizedBox(height: 12),
          // Address row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 20,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(address, style: AppTypography.bodyMedium)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPackageSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Detail Barang',
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.inventory_2_outlined,
                size: 20,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_orderDetail['package']['quantity']}x ${_orderDetail['package']['name']}',
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Berat: ${_orderDetail['package']['weight']}, Dimensi: ${_orderDetail['package']['dimensions']}',
                      style: AppTypography.bodySmall.copyWith(
                        color:
                            AppColors.textSecondary, // AppColors.textSecondary
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionsSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Instruksi Khusus',
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.description_outlined,
                size: 20,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _orderDetail['instructions'],
                  style: AppTypography.bodyMedium,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
        top: 16,
      ),
      decoration: BoxDecoration(
        color: AppColors.backgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isArriving ? null : _arriveAtLocation,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryBlue, // AppColors.primaryBlue
          foregroundColor: AppColors.textWhite,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isArriving
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
            : Text(
                'Tiba di Lokasi Pengantaran',
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.textWhite,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}
