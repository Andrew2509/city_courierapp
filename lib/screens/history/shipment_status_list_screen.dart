import 'package:city_courierapp/core/config/app_typography.dart';
import 'package:city_courierapp/models/shipping/shipment_model.dart';
import 'package:city_courierapp/screens/home/tracking/tracking_detail_screen.dart';
import 'package:city_courierapp/services/api_service.dart';
import 'package:city_courierapp/services/shipping/shipment_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ShipmentStatusListScreen extends StatefulWidget {
  final String status;
  final String title;

  const ShipmentStatusListScreen({
    super.key,
    required this.status,
    required this.title,
  });

  @override
  State<ShipmentStatusListScreen> createState() =>
      _ShipmentStatusListScreenState();
}

class _ShipmentStatusListScreenState extends State<ShipmentStatusListScreen> {
  bool _isLoading = true;
  List<ShipmentModel> _shipments = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchShipments();
  }

  Future<void> _fetchShipments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result =
          await ShipmentService.getUserShipments(status: widget.status);

      if (!mounted) return;
      if (result['success'] == true) {
        setState(() {
          _shipments = result['data'] as List<ShipmentModel>;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Gagal memuat data';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Terjadi kesalahan: $e';
        _isLoading = false;
      });
    }
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(amount);
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    const primaryColor = Color(0xFFEC5B13);
    final scaffoldBg =
        isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF9FAFB);
    final surfaceBg = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final inkPrimary = isDarkMode ? Colors.white : const Color(0xFF0F172A);
    final inkSecondary =
        isDarkMode ? Colors.grey.shade400 : const Color(0xFF64748B);
    final borderColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: surfaceBg,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: inkPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title,
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 17,
            color: inkPrimary,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: borderColor),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchShipments,
        color: primaryColor,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: primaryColor),
              )
            : _errorMessage != null
                ? _buildErrorView(primaryColor, inkSecondary)
                : _shipments.isEmpty
                    ? _buildEmptyView(isDarkMode, inkPrimary, inkSecondary)
                    : _buildShipmentList(isDarkMode),
      ),
    );
  }

  Widget _buildErrorView(Color primaryColor, Color inkSecondary) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: Color(0xFFDC2626),
            ),
            const SizedBox(height: 14),
            Text(
              _errorMessage ?? 'Terjadi kesalahan',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(
                fontSize: 13.5,
                color: inkSecondary,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: _fetchShipments,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: const Size(160, 48),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                textStyle: AppTypography.titleSmall.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView(
    bool isDarkMode,
    Color inkPrimary,
    Color inkSecondary,
  ) {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 72,
                  color: isDarkMode ? Colors.white12 : const Color(0xFFCBD5E1),
                ),
                const SizedBox(height: 16),
                Text(
                  'Belum ada pengiriman',
                  style: AppTypography.titleMedium.copyWith(
                    color: inkPrimary,
                    fontSize: 15.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tidak ada pengiriman ${widget.title.toLowerCase()} saat ini.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySmall.copyWith(
                    color: inkSecondary,
                    fontSize: 13.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildShipmentList(bool isDarkMode) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _shipments.length,
      itemBuilder: (context, index) {
        final shipment = _shipments[index];
        return _buildShipmentCard(shipment, isDarkMode);
      },
    );
  }

  Widget _buildShipmentCard(ShipmentModel shipment, bool isDarkMode) {
    const primaryColor = Color(0xFFEC5B13);
    final surfaceBg = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final inkPrimary = isDarkMode ? Colors.white : const Color(0xFF0F172A);
    final inkSecondary =
        isDarkMode ? Colors.grey.shade400 : const Color(0xFF64748B);
    final borderColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE2E8F0);
    final dividerColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.06)
        : const Color(0xFFF1F5F9);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: surfaceBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          if (!isDarkMode)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      shipment.trackingNumber ?? shipment.orderNumber,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        color: primaryColor,
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormat('dd MMM yyyy').format(shipment.createdAt),
                  style: AppTypography.caption.copyWith(
                    color: inkSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: primaryColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    shipment.deliveryAddress,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall.copyWith(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: inkPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.person_outline, size: 16, color: inkSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    shipment.recipientName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall.copyWith(
                      color: inkSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            if (shipment.isDropoff &&
                shipment.dropPointName != null &&
                shipment.dropPointName!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.store_mall_directory_outlined,
                    size: 16,
                    color: primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Drop Point: ${shipment.dropPointName!}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(
                        color: primaryColor,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            Divider(height: 24, color: dividerColor),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Biaya',
                        style: AppTypography.caption.copyWith(
                          color: inkSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatCurrency(shipment.totalPrice),
                        style: AppTypography.titleSmall.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: inkPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => _navigateToDetail(shipment),
                  style: TextButton.styleFrom(
                    foregroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: AppTypography.titleSmall.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Detail'),
                      SizedBox(width: 2),
                      Icon(Icons.chevron_right_rounded, size: 18),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _navigateToDetail(ShipmentModel shipment) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFFEC5B13)),
      ),
    );

    try {
      final data = await ApiService.trackShipment(shipment.orderNumber);
      if (!mounted) return;
      Navigator.pop(context);

      if (data != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TrackingDetailScreen(trackingData: data),
          ),
        );
      } else {
        _showBasicDetailSheet(shipment);
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showBasicDetailSheet(shipment);
    }
  }

  void _showBasicDetailSheet(ShipmentModel shipment) {
    const primaryColor = Color(0xFFEC5B13);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final inkPrimary = isDarkMode ? Colors.white : const Color(0xFF0F172A);
    final inkSecondary =
        isDarkMode ? Colors.grey.shade400 : const Color(0xFF64748B);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.white24
                        : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Detail Pengiriman',
                style: AppTypography.titleMedium.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: inkPrimary,
                ),
              ),
              const SizedBox(height: 16),
              _detailRow(
                'No. Resi',
                shipment.trackingNumber ?? shipment.orderNumber,
                inkPrimary: inkPrimary,
                inkSecondary: inkSecondary,
                valueColor: primaryColor,
              ),
              _detailRow(
                'Status',
                shipment.statusLabel,
                inkPrimary: inkPrimary,
                inkSecondary: inkSecondary,
                valueColor: primaryColor,
              ),
              _detailRow(
                'Penerima',
                shipment.recipientName,
                inkPrimary: inkPrimary,
                inkSecondary: inkSecondary,
              ),
              _detailRow(
                'No. HP Penerima',
                shipment.recipientPhone,
                inkPrimary: inkPrimary,
                inkSecondary: inkSecondary,
              ),
              _detailRow(
                'Alamat Tujuan',
                shipment.deliveryAddress,
                inkPrimary: inkPrimary,
                inkSecondary: inkSecondary,
              ),
              _detailRow(
                'Berat',
                '${shipment.weight} kg',
                inkPrimary: inkPrimary,
                inkSecondary: inkSecondary,
              ),
              _detailRow(
                'Total Biaya',
                _formatCurrency(shipment.totalPrice),
                inkPrimary: inkPrimary,
                inkSecondary: inkSecondary,
              ),
              if (shipment.isDropoff)
                _detailRow(
                  'Metode',
                  'Dropoff (Antar ke Drop Point)',
                  inkPrimary: inkPrimary,
                  inkSecondary: inkSecondary,
                  valueColor: primaryColor,
                ),
              if (shipment.dropPointName != null &&
                  shipment.dropPointName!.isNotEmpty)
                _detailRow(
                  'Drop Point',
                  '${shipment.dropPointName!}${shipment.dropPointAddress != null && shipment.dropPointAddress!.isNotEmpty ? '\n${shipment.dropPointAddress!}' : ''}',
                  inkPrimary: inkPrimary,
                  inkSecondary: inkSecondary,
                ),
              if (shipment.vehicleType != null &&
                  shipment.vehicleType!.isNotEmpty)
                _detailRow(
                  shipment.isDropoff ? 'Layanan' : 'Jenis Kendaraan',
                  shipment.isDropoff
                      ? shipment.vehicleType!
                      : (shipment.vehicleType!.toLowerCase() == 'mobil'
                            ? 'Mobil'
                            : 'Motor'),
                  inkPrimary: inkPrimary,
                  inkSecondary: inkSecondary,
                ),
              if (shipment.courierName != null)
                _detailRow(
                  'Kurir',
                  shipment.courierName!,
                  inkPrimary: inkPrimary,
                  inkSecondary: inkSecondary,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(
    String label,
    String value, {
    required Color inkPrimary,
    required Color inkSecondary,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: AppTypography.bodySmall.copyWith(
                color: inkSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.bodySmall.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor ?? inkPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
