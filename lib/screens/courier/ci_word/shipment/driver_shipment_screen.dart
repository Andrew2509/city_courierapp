import 'package:flutter/material.dart';
import 'package:city_courierapp/main.dart';
import 'package:city_courierapp/screens/courier/ci_word/home/driver_home_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/earnings/driver_earnings_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/profile/driver_profile_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/shipment/driver_detail_shipment_screen.dart';

import 'package:city_courierapp/screens/courier/ci_word/delivery/driver_delivery_flow_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/widgets/driver_bottom_navigation.dart';
import 'package:city_courierapp/services/courier/courier_order_service.dart';

class DriverShipmentScreen extends StatefulWidget {
  const DriverShipmentScreen({super.key});

  @override
  State<DriverShipmentScreen> createState() => _DriverShipmentScreenState();
}

class _DriverShipmentScreenState extends State<DriverShipmentScreen> with RouteAware {
  List<Map<String, dynamic>> _allShipments = [];
  bool _isLoading = true;
  int _selectedTabIndex = 0;

  final List<String> _tabs = [
    'Semua',
    'Menunggu',
    'Berjalan',
    'Selesai',
    'Dibatalkan'
  ];

  @override
  void initState() {
    super.initState();
    _fetchShipments();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    // Called when the route above this one is popped, making this screen visible.
    _fetchShipments();
  }

  Future<void> _fetchShipments() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // Ambil semua pesanan yang di-assign ke driver ini
      final activeOrderResult = await CourierOrderService.getActiveOrder();
      final assignedResult = await CourierOrderService.getOrdersByStatus('assigned');
      final pickingUpResult = await CourierOrderService.getOrdersByStatus('picking_up');
      final deliveringResult = await CourierOrderService.getOrdersByStatus('delivering');
      final historyResult = await CourierOrderService.getOrdersByStatus('delivered');
      final cancelledResult = await CourierOrderService.getOrdersByStatus('cancelled');

      if (mounted) {
        setState(() {
          _allShipments = [];

          // Tambahkan pesanan aktif saat ini jika ada
          if (activeOrderResult['success'] == true && activeOrderResult['data'] != null) {
            final active = activeOrderResult['data'] as Map<String, dynamic>;
            _allShipments.add(active);
          }

          // Tambahkan pesanan yang sedang berjalan
          for (final result in [assignedResult, pickingUpResult, deliveringResult, historyResult, cancelledResult]) {
            if (result['success'] == true && result['data'] is List) {
              _allShipments.addAll(List<Map<String, dynamic>>.from(result['data']));
            }
          }

          // Hapus duplikat berdasarkan ID
          final Map<int, Map<String, dynamic>> uniqueShipments = {};
          for (var shipment in _allShipments) {
            if (shipment['id'] != null) {
              uniqueShipments[shipment['id'] as int] = shipment;
            }
          }
          _allShipments = uniqueShipments.values.toList();

          // Urutkan dari yang terbaru
          _allShipments.sort((a, b) {
            int idA = a['id'] ?? 0;
            int idB = b['id'] ?? 0;
            return idB.compareTo(idA);
          });

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengambil data: $e')),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredShipments {
    if (_selectedTabIndex == 0) return _allShipments; // Semua
    
    return _allShipments.where((shipment) {
      final status = shipment['status'] ?? 'pending';
      switch (_selectedTabIndex) {
        case 1: // Menunggu
          return status == 'pending' || status == 'assigned';
        case 2: // Berjalan
          return status == 'picking_up' || status == 'delivering';
        case 3: // Selesai
          return status == 'delivered';
        case 4: // Dibatalkan
          return status == 'cancelled';
        default:
          return true;
      }
    }).toList();
  }

  String _formatCurrency(double amount) {
    return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Shipment',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      // Filter action
                    },
                    child: const Icon(
                      Icons.tune,
                      color: Color(0xFF1A1A1A),
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
            
            // Tabs
            Container(
              color: Colors.white,
              width: double.infinity,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: List.generate(_tabs.length, (index) {
                    final isActive = _selectedTabIndex == index;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedTabIndex = index;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: isActive ? const Color(0xFFFF5A00) : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                        child: Text(
                          _tabs[index],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                            color: isActive ? const Color(0xFFFF5A00) : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
            
            // Divider below tabs
            Container(
              height: 1,
              color: const Color(0xFFF1F5F9),
            ),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF5A00)))
                  : RefreshIndicator(
                      onRefresh: _fetchShipments,
                      color: const Color(0xFFFF5A00),
                      child: _filteredShipments.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                              itemCount: _filteredShipments.length,
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemBuilder: (context, index) {
                                return _buildShipmentCard(_filteredShipments[index]);
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
      
      // We will place Riwayat Shipment button floating right above Bottom Nav if requested, but for now BottomNav is enough
      bottomNavigationBar: DriverBottomNavigation(
        currentIndex: 1,
        onTap: (index) {
          if (index == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const DriverHomeScreen()),
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
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.6,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 80,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Belum ada data shipment',
              style: TextStyle(
                color: Colors.grey[500],
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShipmentCard(Map<String, dynamic> shipment) {
    final status = shipment['status'] ?? 'pending';
    
    // Status translation & color mapping
    String displayStatus = 'Menunggu';
    Color badgeBgColor = const Color(0xFFF1F5F9);
    Color badgeTextColor = const Color(0xFF475569);
    Color arrowColor = const Color(0xFF1A1A1A);
    bool isActive = false;

    if (status == 'assigned' || status == 'picking_up') {
      displayStatus = 'Di Pickup';
      badgeBgColor = const Color(0xFFDCFCE7);
      badgeTextColor = const Color(0xFF16A34A);
      arrowColor = const Color(0xFFFF5A00);
      isActive = true;
    } else if (status == 'delivering') {
      displayStatus = 'Diperjalanan';
      badgeBgColor = const Color(0xFFFFEDD5);
      badgeTextColor = const Color(0xFFEA580C);
      arrowColor = const Color(0xFFFF5A00);
      isActive = true;
    } else if (status == 'delivered') {
      displayStatus = 'Selesai';
      badgeBgColor = const Color(0xFFF1F5F9);
      badgeTextColor = const Color(0xFF475569);
      arrowColor = const Color(0xFF1A1A1A);
    } else if (status == 'cancelled') {
      displayStatus = 'Dibatalkan';
      badgeBgColor = const Color(0xFFFEE2E2);
      badgeTextColor = const Color(0xFFDC2626);
    }

    // Sender & Receiver
    final senderName = shipment['sender_name'] ?? shipment['merchant']?['name'] ?? 'Toko Elektronik';
    final receiverName = shipment['receiver_name'] ?? 'Penerima';
    final estTime = shipment['estimated_time'] ?? '11:30 - 12:00 WIB';
    
    // Price
    final double price = double.tryParse(shipment['price']?.toString() ?? '0') ?? 0;
    final isCOD = shipment['payment_method'] == 'COD';

    return GestureDetector(
      onTap: () {
        if (isActive) {
          // If active (pickup/delivering), go to pickup process screen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DriverDeliveryFlowScreen(order: shipment),
            ),
          );
        } else {
          // If done/cancelled, go to order detail
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DriverDetailShipmentScreen(shipment: shipment),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x05000000),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  shipment['tracking_number'] ?? shipment['order_number'] ?? '#SH-${shipment['id'] ?? '0000'}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFFF5A00),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: badgeBgColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        displayStatus,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: badgeTextColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.chevron_right,
                      color: arrowColor,
                      size: 20,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Info Grid
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pengirim',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        senderName,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Penerima',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        receiverName,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        status == 'delivered' ? 'Selesai Pada' : 'Estimasi Tiba',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
                        textAlign: TextAlign.right,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        status == 'delivered' ? (shipment['updated_at']?.toString().substring(11, 16) ?? '09:45 WIB') : estTime,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A)),
                        textAlign: TextAlign.right,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Divider
            Container(
              height: 1,
              color: const Color(0xFFF1F5F9),
            ),
            const SizedBox(height: 12),
            
            // Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Jarak • ${shipment['distance_km'] ?? '5.2'} km',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
                Row(
                  children: [
                    if (isCOD) ...[
                      const Text(
                        'COD',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      _formatCurrency(price > 0 ? price : 75000), // Default mock price if 0
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: isCOD ? const Color(0xFF22C55E) : const Color(0xFF1A1A1A),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
