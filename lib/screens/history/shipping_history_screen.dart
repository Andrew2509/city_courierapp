import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:city_courierapp/screens/widgets/history/shipping_card_widget.dart';
import 'package:city_courierapp/screens/home/tracking/tracking_detail_screen.dart';
import 'package:city_courierapp/screens/widgets/home/bottom_nav_bar.dart';
import 'package:city_courierapp/models/shipping/shipment_model.dart';
import 'package:city_courierapp/services/shipping/shipment_service.dart';

class ShippingHistoryScreen extends StatefulWidget {
  const ShippingHistoryScreen({super.key});

  @override
  State<ShippingHistoryScreen> createState() => _ShippingHistoryScreenState();
}

class _ShippingHistoryScreenState extends State<ShippingHistoryScreen> {
  final TextEditingController searchController = TextEditingController();
  bool _isLoading = true;
  List<ShipmentModel> _activeShipments = [];
  List<ShipmentModel> _completedShipments = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Fetch active shipments (everything except delivered and cancelled)
      final activeResult = await ShipmentService.getUserShipments(
        status: 'pending,confirmed,assigned,picking_up,picked_up,delivering,in_transit',
      );
      
      // Fetch completed shipments
      final completedResult = await ShipmentService.getUserShipments(
        status: 'delivered',
      );

      if (mounted) {
        if (activeResult['success'] == true && completedResult['success'] == true) {
          setState(() {
            _activeShipments = activeResult['data'] as List<ShipmentModel>;
            _completedShipments = completedResult['data'] as List<ShipmentModel>;
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = activeResult['message'] ?? completedResult['message'] ?? 'Gagal memuat data';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Terjadi kesalahan: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFFEC5B13); 
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: isDarkMode ? Colors.white : const Color(0xFF0F172A)),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Riwayat Pengiriman',
            style: TextStyle(
              color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          centerTitle: true,
          bottom: TabBar(
            indicatorColor: primaryColor,
            indicatorWeight: 3,
            labelColor: primaryColor,
            unselectedLabelColor: isDarkMode ? Colors.grey.shade500 : const Color(0xFF64748B), 
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
            dividerColor: isDarkMode ? Colors.white.withOpacity(0.05) : const Color(0xFFE2E8F0), 
            tabs: const [
              Tab(text: 'Sedang Dikirim'),
              Tab(text: 'Selesai'),
            ],
          ),
        ),
        body: RefreshIndicator(
          onRefresh: _fetchData,
          color: primaryColor,
          child: Stack(
            children: [
              Column(
                children: [
                  // Search Bar (Filter)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.white.withOpacity(0.05) : const Color(0xFFF1F5F9), 
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search, color: Color(0xFF94A3B8), size: 20), 
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: searchController,
                              style: TextStyle(
                                fontSize: 14,
                                color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                              ),
                              decoration: const InputDecoration(
                                hintText: 'Cari No. Resi...',
                                hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(vertical: 12),
                              ),
                              onChanged: (value) {
                                // Simple search logic can be implemented here
                                setState(() {});
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Tab Views
                  Expanded(
                    child: _isLoading 
                      ? const Center(child: CircularProgressIndicator())
                      : _errorMessage != null
                        ? _buildErrorView()
                        : TabBarView(
                            children: [
                              _buildShipmentList(_filterShipments(_activeShipments), primaryColor, isDarkMode),
                              _buildShipmentList(_filterShipments(_completedShipments), primaryColor, isDarkMode),
                            ],
                          ),
                  ),
                ],
              ),
              const BottomNavBar(activeIndex: 2),
            ],
          ),
        ),
      ),
    );
  }

  List<ShipmentModel> _filterShipments(List<ShipmentModel> list) {
    final query = searchController.text.toLowerCase();
    if (query.isEmpty) return list;
    return list.where((s) => (s.trackingNumber ?? s.orderNumber).toLowerCase().contains(query)).toList();
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(_errorMessage ?? 'Terjadi kesalahan'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _fetchData,
            child: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }

  Widget _buildShipmentList(List<ShipmentModel> shipments, Color primaryColor, bool isDarkMode) {
    if (shipments.isEmpty) {
      return ListView( // Wrap in ListView for RefreshIndicator
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history_outlined, size: 64, color: isDarkMode ? Colors.white12 : Colors.grey.shade200),
                const SizedBox(height: 16),
                Text(
                  'Belum ada riwayat',
                  style: TextStyle(
                    color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), // Bottom padding for navbar
      itemCount: shipments.length,
      itemBuilder: (context, index) {
        final item = shipments[index];
        return ShippingCardWidget(
          orderId: item.trackingNumber ?? item.orderNumber,
          status: item.statusLabel,
          senderName: item.senderName,
          senderLoc: item.pickupAddress,
          receiverName: item.recipientName,
          receiverLoc: item.deliveryAddress,
          dateTime: DateFormat('dd MMM yyyy, HH:mm').format(item.createdAt),
          primaryColor: primaryColor,
          isDarkMode: isDarkMode,
          onTrackPressed: () {
            final resi = item.trackingNumber ?? item.orderNumber;
            if (resi.isNotEmpty) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TrackingDetailScreen(
                    trackingNumber: resi,
                  ),
                ),
              ).then((_) => _fetchData());
            }
          },
        );
      },
    );
  }
}
