import 'package:flutter/material.dart';
import 'package:city_courierapp/models/shipping/shipment_model.dart';
import 'package:city_courierapp/services/shipping/shipment_service.dart';
import 'package:city_courierapp/services/api_service.dart';
import 'package:city_courierapp/screens/home/tracking/tracking_detail_screen.dart';
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
  State<ShipmentStatusListScreen> createState() => _ShipmentStatusListScreenState();
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

    final result = await ShipmentService.getUserShipments(status: widget.status);

    if (mounted) {
      if (result['success'] == true) {
        setState(() {
          _shipments = result['data'] as List<ShipmentModel>;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = result['message'];
          _isLoading = false;
        });
      }
    }
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp',
      decimalDigits: 0,
    ).format(amount);
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFFEC5B13);

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDarkMode ? Colors.white : Colors.black,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchShipments,
        color: primaryColor,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? _buildErrorView()
                : _shipments.isEmpty
                    ? _buildEmptyView(isDarkMode)
                    : _buildShipmentList(isDarkMode),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(_errorMessage ?? 'Terjadi kesalahan'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _fetchShipments,
            child: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView(bool isDarkMode) {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 80,
                color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
              ),
              const SizedBox(height: 16),
              Text(
                'Tidak ada pengiriman ${widget.title.toLowerCase()}',
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
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
    final primaryColor = const Color(0xFFEC5B13);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? Colors.grey[800]! : Colors.grey[200]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    shipment.trackingNumber ?? shipment.orderNumber,
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  DateFormat('dd MMM yyyy').format(shipment.createdAt),
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.location_on_outlined, size: 16, color: primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    shipment.deliveryAddress,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.person_outline, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  shipment.recipientName,
                  style: TextStyle(
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Biaya',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      _formatCurrency(shipment.totalPrice),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => _navigateToDetail(shipment),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Detail',
                        style: TextStyle(color: primaryColor, fontSize: 13),
                      ),
                      Icon(Icons.chevron_right, color: primaryColor, size: 18),
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
    // Show loading indicator
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
      Navigator.pop(context); // Dismiss loading

      if (data != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TrackingDetailScreen(trackingData: data),
          ),
        );
      } else {
        // Fallback: show a basic detail sheet with the shipment model data
        _showBasicDetailSheet(shipment);
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Dismiss loading
      _showBasicDetailSheet(shipment);
    }
  }

  void _showBasicDetailSheet(ShipmentModel shipment) {
    final primaryColor = const Color(0xFFEC5B13);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

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
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Detail Pengiriman',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              _detailRow('No. Resi', shipment.trackingNumber ?? shipment.orderNumber, primaryColor),
              _detailRow('Status', shipment.statusLabel, primaryColor),
              _detailRow('Penerima', shipment.recipientName),
              _detailRow('No. HP Penerima', shipment.recipientPhone),
              _detailRow('Alamat Tujuan', shipment.deliveryAddress),
              _detailRow('Berat', '${shipment.weight} kg'),
              _detailRow('Total Biaya', _formatCurrency(shipment.totalPrice)),
              if (shipment.courierName != null)
                _detailRow('Kurir', shipment.courierName!),
              if (shipment.trackingNumber != null)
                _detailRow('No. Resi', shipment.trackingNumber!),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, [Color? valueColor]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
