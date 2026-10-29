import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:city_courierapp/main.dart';
import 'package:city_courierapp/models/shipping/schedule_time_config.dart';
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
    'Pesanan Baru',
    'Hari Ini',
    'Terjadwal',
    'Dalam Pickup',
    'Selesai',
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
    _fetchShipments();
  }

  bool _isOrderScheduled(Map<String, dynamic> s) {
    final nested = s['shipment'] is Map ? s['shipment'] as Map : null;
    final rawFlag = s['scheduled_pickup'] ?? nested?['scheduled_pickup'];
    final scheduledAt = s['pickup_scheduled_at'] ?? nested?['pickup_scheduled_at'];
    final pickupTime = (s['pickup_time'] ?? nested?['pickup_time'] ?? '').toString().trim();
    return rawFlag == true ||
        rawFlag == 1 ||
        rawFlag == '1' ||
        rawFlag == 'true' ||
        (scheduledAt != null && scheduledAt.toString().trim().isNotEmpty) ||
        pickupTime.isNotEmpty;
  }

  dynamic _getScheduledAt(Map<String, dynamic> s) {
    final nested = s['shipment'] is Map ? s['shipment'] as Map : null;
    return s['pickup_scheduled_at'] ?? nested?['pickup_scheduled_at'];
  }

  String _getPickupTime(Map<String, dynamic> s) {
    final nested = s['shipment'] is Map ? s['shipment'] as Map : null;
    final raw = (s['pickup_time'] ?? nested?['pickup_time'] ?? '').toString().trim();
    return ScheduleTimeConfig.extractTimeOnly(
      raw,
      scheduledAtFallback: _getScheduledAt(s),
    );
  }

  Future<void> _fetchShipments() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final availableResult = await CourierOrderService.getAvailableOrders();
      final activeOrderResult = await CourierOrderService.getActiveOrder();
      final assignedResult = await CourierOrderService.getOrdersByStatus('assigned');
      final pickingUpResult = await CourierOrderService.getOrdersByStatus('picking_up');
      final pickedUpResult = await CourierOrderService.getOrdersByStatus('picked_up');
      final deliveringResult = await CourierOrderService.getOrdersByStatus('delivering');
      final historyResult = await CourierOrderService.getOrdersByStatus('delivered');
      final cancelledResult = await CourierOrderService.getOrdersByStatus('cancelled');

      if (mounted) {
        setState(() {
          final List<Map<String, dynamic>> combined = [];

          // 1. Pesanan baru yang tersedia
          if (availableResult['success'] == true && availableResult['data'] is List) {
            combined.addAll(List<Map<String, dynamic>>.from(availableResult['data']));
          }

          // 2. Pesanan aktif saat ini
          if (activeOrderResult['success'] == true && activeOrderResult['data'] != null) {
            final active = activeOrderResult['data'] as Map<String, dynamic>;
            combined.add(active);
          }

          // 3. Status-status lainnya
          for (final result in [
            assignedResult,
            pickingUpResult,
            pickedUpResult,
            deliveringResult,
            historyResult,
            cancelledResult,
          ]) {
            if (result['success'] == true && result['data'] is List) {
              combined.addAll(List<Map<String, dynamic>>.from(result['data']));
            }
          }

          // Hapus duplikat berdasarkan ID
          final Map<dynamic, Map<String, dynamic>> uniqueMap = {};
          for (var item in combined) {
            final id = item['id'];
            if (id != null) {
              uniqueMap[id] = item;
            }
          }

          _allShipments = uniqueMap.values.toList();

          // Urutkan default: yang terbaru
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
    final now = DateTime.now();

    switch (_selectedTabIndex) {
      case 0: // Semua
        return _allShipments;

      case 1: // Pesanan Baru (pending)
        return _allShipments.where((s) => (s['status'] ?? 'pending') == 'pending').toList();

      case 2: // Pickup Hari Ini
        final list = _allShipments.where((s) {
          final status = s['status'] ?? 'pending';
          if (status == 'delivered' || status == 'cancelled') return false;

          final scheduledAt = _getScheduledAt(s);
          final isScheduled = _isOrderScheduled(s);

          if (isScheduled && scheduledAt != null) {
            return ScheduleTimeConfig.isScheduledForToday(scheduledAt, referenceNow: now);
          }

          // Jika non-terjadwal, cek tanggal pesanan dibuat
          final createdAt = s['created_at'];
          if (createdAt != null) {
            final createdDt = ScheduleTimeConfig.parseDateTimeSafe(createdAt);
            if (createdDt != null) {
              return createdDt.year == now.year &&
                     createdDt.month == now.month &&
                     createdDt.day == now.day;
            }
          }
          return false;
        }).toList();

        // Urutkan berdasarkan jam pickup terdekat
        list.sort((a, b) {
          final dtA = ScheduleTimeConfig.parseDateTimeSafe(_getScheduledAt(a)) ??
              ScheduleTimeConfig.parseDateTimeSafe(a['created_at']) ??
              DateTime.now();
          final dtB = ScheduleTimeConfig.parseDateTimeSafe(_getScheduledAt(b)) ??
              ScheduleTimeConfig.parseDateTimeSafe(b['created_at']) ??
              DateTime.now();
          return dtA.compareTo(dtB);
        });
        return list;

      case 3: // Pickup Terjadwal (jadwal mendatang / assigned)
        return _allShipments.where((s) {
          final status = s['status'] ?? 'pending';
          final isScheduled = _isOrderScheduled(s);
          return isScheduled && (status == 'assigned' || status == 'pending');
        }).toList();

      case 4: // Dalam Proses Pickup (picking_up)
        return _allShipments.where((s) => s['status'] == 'picking_up').toList();

      case 5: // Selesai / Terkirim
        return _allShipments.where((s) {
          final status = s['status'] ?? '';
          return status == 'picked_up' || status == 'delivering' || status == 'delivered';
        }).toList();

      default:
        return _allShipments;
    }
  }

  String _formatCurrency(double amount) {
    return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  void _openDialer(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _openMaps(double? lat, double? lng, String? address) async {
    if (lat != null && lng != null && lat != 0 && lng != 0) {
      final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }
    if (address != null && address.isNotEmpty) {
      final encoded = Uri.encodeComponent(address);
      final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$encoded');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  Future<void> _handleAcceptOrder(Map<String, dynamic> shipment) async {
    final orderId = shipment['id']?.toString() ?? '';
    final res = await CourierOrderService.acceptPickupRequest(orderId);
    if (!mounted) return;

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pesanan berhasil diterima! Masuk ke Pickup Terjadwal.'),
          backgroundColor: Colors.green,
        ),
      );
      _fetchShipments();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Gagal menerima pesanan'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleRejectOrder(Map<String, dynamic> shipment) async {
    final orderId = shipment['id']?.toString() ?? '';
    final res = await CourierOrderService.rejectPickupRequest(orderId);
    if (!mounted) return;

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pesanan ditolak.'),
          backgroundColor: Colors.grey,
        ),
      );
      _fetchShipments();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Gagal menolak pesanan'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleStartPickup(Map<String, dynamic> shipment) async {
    final scheduledAt = _getScheduledAt(shipment);
    final isScheduled = _isOrderScheduled(shipment);

    // Cek schedule tolerance jika order terjadwal
    if (isScheduled && scheduledAt != null) {
      if (!ScheduleTimeConfig.canStartPickup(scheduledAt)) {
        final timeStr = _getPickupTime(shipment);
        final statusLabel = ScheduleTimeConfig.getCourierPickupStatusLabel(scheduledAt);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Penjemputan belum dapat dimulai ($statusLabel). Anda dapat mulai 30 menit sebelum jadwal pickup ($timeStr).',
            ),
            backgroundColor: const Color(0xFFD97706),
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }
    }

    final orderId = shipment['id']?.toString() ?? '';
    final res = await CourierOrderService.updateOrderStatus(
      orderId: orderId,
      status: 'picking_up',
    );

    if (!mounted) return;

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Status diubah: Menuju lokasi pickup!'),
          backgroundColor: Colors.green,
        ),
      );
      final updatedOrder = (res['data'] as Map<String, dynamic>?) ?? shipment;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DriverDeliveryFlowScreen(order: updatedOrder),
        ),
      ).then((_) => _fetchShipments());
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Gagal memulai penjemputan'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Manajemen Shipment',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  IconButton(
                    onPressed: _fetchShipments,
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: Color(0xFFFF5A00),
                      size: 22,
                    ),
                    tooltip: 'Muat ulang data',
                  ),
                ],
              ),
            ),

            // Horizontal Tab Bar
            Container(
              color: Colors.white,
              width: double.infinity,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
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
                              width: 2.5,
                            ),
                          ),
                        ),
                        child: Text(
                          _tabs[index],
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
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
              color: const Color(0xFFE2E8F0),
            ),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFFFF5A00)),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchShipments,
                      color: const Color(0xFFFF5A00),
                      child: _filteredShipments.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
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
    final tabName = _tabs[_selectedTabIndex];
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.55,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFFFF7ED),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                size: 56,
                color: Color(0xFFFF5A00),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Tidak Ada Pesanan ($tabName)',
              style: const TextStyle(
                color: Color(0xFF1E293B),
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Belum ada penugasan pengiriman pada kategori ini.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShipmentCard(Map<String, dynamic> shipment) {
    final nested = shipment['shipment'] is Map ? shipment['shipment'] as Map : null;
    final status = shipment['status'] ?? 'pending';
    final trackingNumber = shipment['tracking_number'] ?? shipment['order_number'] ?? '#CC-${shipment['id']}';
    final vehicleType = (shipment['vehicle'] ?? shipment['vehicle_type'] ?? nested?['vehicle'] ?? 'motor').toString().toLowerCase();
    final isCar = vehicleType == 'mobil';

    final isScheduled = _isOrderScheduled(shipment);
    final scheduledAt = _getScheduledAt(shipment);
    final pickupTimeStr = _getPickupTime(shipment);
    final scheduledDt = ScheduleTimeConfig.parseDateTimeSafe(scheduledAt);
    final displayDateStr = scheduledDt != null ? ScheduleTimeConfig.formatDisplayDay(scheduledDt) : '';

    // Schedule status calculation
    final isOverdue = ScheduleTimeConfig.isPickupOverdue(scheduledAt);
    final canPickup = ScheduleTimeConfig.canStartPickup(scheduledAt);
    final statusLabel = ScheduleTimeConfig.getCourierPickupStatusLabel(scheduledAt);

    // Status translations
    String badgeText = 'Pesanan Baru';
    Color badgeBg = const Color(0xFFFEF3C7);
    Color badgeFg = const Color(0xFFB45309);

    if (status == 'assigned') {
      badgeText = isScheduled ? 'Terjadwal' : 'Ditugaskan';
      badgeBg = const Color(0xFFE0E7FF);
      badgeFg = const Color(0xFF4338CA);
    } else if (status == 'picking_up') {
      badgeText = 'Proses Pickup';
      badgeBg = const Color(0xFFDBEAFE);
      badgeFg = const Color(0xFF1D4ED8);
    } else if (status == 'picked_up') {
      badgeText = 'Paket Diambil';
      badgeBg = const Color(0xFFDCFCE7);
      badgeFg = const Color(0xFF15803D);
    } else if (status == 'delivering') {
      badgeText = 'Dalam Perjalanan';
      badgeBg = const Color(0xFFFFEDD5);
      badgeFg = const Color(0xFFC2410C);
    } else if (status == 'delivered') {
      badgeText = 'Terkirim';
      badgeBg = const Color(0xFFF1F5F9);
      badgeFg = const Color(0xFF475569);
    } else if (status == 'cancelled') {
      badgeText = 'Dibatalkan';
      badgeBg = const Color(0xFFFEE2E2);
      badgeFg = const Color(0xFFB91C1C);
    }

    final senderName = shipment['sender_name'] ?? shipment['customer_name'] ?? 'Pengirim';
    final pickupAddress = shipment['pickup_address'] ?? 'Alamat pickup belum ditentukan';
    final receiverName = shipment['receiver_name'] ?? 'Penerima';
    final deliveryAddress = shipment['delivery_address'] ?? 'Alamat tujuan belum ditentukan';
    final packageDesc = shipment['package_description'] ?? 'Paket Standar';
    final weight = shipment['package_weight'] ?? '1';
    final double price = double.tryParse(shipment['price']?.toString() ?? '0') ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DriverDetailShipmentScreen(shipment: shipment),
              ),
            ).then((_) => _fetchShipments());
          },
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Resi + Vehicle Badge + Status Badge
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        trackingNumber,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'monospace',
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    // Vehicle Badge (Motor / Mobil)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: isCar ? const Color(0xFFEFF6FF) : const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isCar ? const Color(0xFFBFDBFE) : const Color(0xFFBBF7D0),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isCar ? Icons.directions_car : Icons.two_wheeler,
                            size: 13,
                            color: isCar ? const Color(0xFF1D4ED8) : const Color(0xFF15803D),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isCar ? 'Mobil' : 'Motor',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isCar ? const Color(0xFF1D4ED8) : const Color(0xFF15803D),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: badgeFg,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Scheduled Pickup Banner (jika terjadwal)
                if (isScheduled) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isOverdue ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isOverdue ? const Color(0xFFFECACA) : const Color(0xFFFDE68A),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 16,
                          color: isOverdue ? const Color(0xFFDC2626) : const Color(0xFFD97706),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Jadwal Pickup: ${displayDateStr.isNotEmpty ? '$displayDateStr • ' : ''}${pickupTimeStr.isNotEmpty ? pickupTimeStr : 'Fleksibel'}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isOverdue ? const Color(0xFF991B1B) : const Color(0xFF92400E),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isOverdue
                                ? const Color(0xFFEF4444)
                                : canPickup
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFFF59E0B),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            statusLabel,
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Route (Pickup & Dropoff)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF5A00),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                        Container(
                          width: 1.5,
                          height: 24,
                          color: const Color(0xFFCBD5E1),
                        ),
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: const Color(0xFF16A34A),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$senderName • $pickupAddress',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            '$receiverName • $deliveryAddress',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 10),

                // Package & Price Info
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$packageDesc ($weight kg)',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      _formatCurrency(price),
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFFF5A00),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Contextual Action Buttons
                _buildActionButtons(shipment, status, isScheduled, canPickup),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(
    Map<String, dynamic> shipment,
    String status,
    bool isScheduled,
    bool canPickup,
  ) {
    final senderPhone = shipment['sender_phone'] ?? shipment['customer_phone'];
    final pLat = double.tryParse(shipment['pickup_latitude']?.toString() ?? '');
    final pLng = double.tryParse(shipment['pickup_longitude']?.toString() ?? '');
    final pAddress = shipment['pickup_address'];

    // 1. Pesanan Baru (status: pending) -> [Tolak] & [Terima Pesanan]
    if (status == 'pending') {
      return Row(
        children: [
          Expanded(
            flex: 1,
            child: OutlinedButton(
              onPressed: () => _handleRejectOrder(shipment),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text(
                'Tolak',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: () => _handleAcceptOrder(shipment),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5A00),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: const Text(
                'Terima Pesanan',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      );
    }

    // 2. Terjadwal / Ditugaskan (status: assigned) -> [Hubungi], [Navigasi], [Mulai Pickup]
    if (status == 'assigned') {
      return Row(
        children: [
          if (senderPhone != null) ...[
            IconButton(
              onPressed: () => _openDialer(senderPhone),
              icon: const Icon(Icons.call, size: 18, color: Color(0xFF16A34A)),
              tooltip: 'Hubungi Pengirim',
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFDCFCE7),
                padding: const EdgeInsets.all(8),
              ),
            ),
            const SizedBox(width: 6),
          ],
          IconButton(
            onPressed: () => _openMaps(pLat, pLng, pAddress),
            icon: const Icon(Icons.navigation, size: 18, color: Color(0xFF2563EB)),
            tooltip: 'Navigasi ke Pickup',
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFDBEAFE),
              padding: const EdgeInsets.all(8),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              onPressed: () => _handleStartPickup(shipment),
              style: ElevatedButton.styleFrom(
                backgroundColor: canPickup ? const Color(0xFFFF5A00) : const Color(0xFFCBD5E1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    canPickup ? Icons.play_arrow_rounded : Icons.lock_outline_rounded,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    canPickup ? 'Mulai Pickup' : 'Mulai Pickup (Terkunci)',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // 3. Dalam Proses Pickup (status: picking_up) -> [Navigasi] & [Lanjut ke Pickup]
    if (status == 'picking_up') {
      return Row(
        children: [
          IconButton(
            onPressed: () => _openMaps(pLat, pLng, pAddress),
            icon: const Icon(Icons.navigation, size: 18, color: Color(0xFF2563EB)),
            tooltip: 'Navigasi',
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFDBEAFE),
              padding: const EdgeInsets.all(8),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DriverDeliveryFlowScreen(order: shipment),
                  ),
                ).then((_) => _fetchShipments());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Konfirmasi Barang Diambil',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // 4. Paket Telah Diambil (status: picked_up) -> [Mulai Antar Paket]
    if (status == 'picked_up') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () async {
            final res = await CourierOrderService.updateOrderStatus(
              orderId: shipment['id'].toString(),
              status: 'delivering',
            );
            if (res['success'] == true && mounted) {
              final updated = (res['data'] as Map<String, dynamic>?) ?? shipment;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DriverDeliveryFlowScreen(order: updated),
                ),
              ).then((_) => _fetchShipments());
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF5A00),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.local_shipping_outlined, size: 16),
              SizedBox(width: 6),
              Text(
                'Mulai Antar ke Penerima',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      );
    }

    // 5. Sedang Mengantar (status: delivering) -> [Lanjutkan Pengantaran]
    if (status == 'delivering') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DriverDeliveryFlowScreen(order: shipment),
              ),
            ).then((_) => _fetchShipments());
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF5A00),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.delivery_dining, size: 16),
              SizedBox(width: 6),
              Text(
                'Lanjutkan Pengantaran',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      );
    }

    // 6. Default / Selesai / Batal
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DriverDetailShipmentScreen(shipment: shipment),
            ),
          ).then((_) => _fetchShipments());
        },
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFE2E8F0)),
          padding: const EdgeInsets.symmetric(vertical: 9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: const Text(
          'Lihat Rincian Pengiriman',
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
        ),
      ),
    );
  }
}
