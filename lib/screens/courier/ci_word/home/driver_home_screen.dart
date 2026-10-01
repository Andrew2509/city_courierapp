import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import 'package:city_courierapp/core/config/app_colors.dart';
import 'package:city_courierapp/core/config/app_typography.dart';
import 'package:city_courierapp/screens/courier/ci_word/widgets/driver_bottom_navigation.dart';
import 'package:city_courierapp/services/courier/courier_live_location_service.dart';
import 'package:city_courierapp/services/courier/courier_status_service.dart';
import 'package:city_courierapp/services/courier/courier_order_service.dart';
import 'package:city_courierapp/services/courier/courier_profile_service.dart';
import 'package:city_courierapp/services/courier/pickup_request_polling_service.dart';

import 'package:city_courierapp/screens/courier/ci_word/shipment/driver_detail_shipment_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/delivery/driver_delivery_flow_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/delivery/driver_navigation_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/earnings/driver_earnings_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/shipment/driver_shipment_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/profile/driver_profile_screen.dart';
import 'package:city_courierapp/services/courier/courier_api_service.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  static const Color primaryColor = Color(0xFFFF5A00); // Updated to HTML var(--primary)
  static const Color greenColor = Color(0xFF22C55E);
  
  Map<String, dynamic>? _activeOrder;
  List<Map<String, dynamic>> _pendingTasks = [];
  bool _isLoadingHomeData = false;
  String _courierName = 'Kurir';

  // Stats from GET /api/courier/stats
  int _totalShipments = 0;
  int _activeOrders = 0;
  double _totalEarnings = 0;

  CourierStatusService? _statusService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final statusService = Provider.of<CourierStatusService>(context, listen: false);
      _statusService = statusService;
      statusService.syncWithServer();
      _initLocationService();
      _fetchHomeData();
      _fetchCourierProfile();
      
      if (statusService.isOnline) {
        PickupRequestPollingService.instance.startPolling(context);
      }
      statusService.addListener(_onStatusChange);
    });
  }

  Future<void> _fetchHomeData() async {
    if (_isLoadingHomeData) return;

    setState(() {
      _isLoadingHomeData = true;
    });

    try {
      final activeResult = await CourierOrderService.getActiveOrder();
      final availableResult = await CourierOrderService.getAvailableOrders();
      final statsResult = await CourierApiService.getCourierStats();

      if (mounted) {
        setState(() {
          if (activeResult['success'] == true) {
            _activeOrder = activeResult['data'];
          } else {
            _activeOrder = null;
          }

          if (availableResult['success'] == true) {
            final List<dynamic> orders = availableResult['data'];
            _pendingTasks = orders.map((o) => o as Map<String, dynamic>).toList();
          } else {
            _pendingTasks = [];
          }

          if (statsResult['success'] == true && statsResult['data'] != null) {
            final s = statsResult['data'] as Map<String, dynamic>;
            _totalShipments = (s['total_shipments'] ?? 0) as int;
            _activeOrders = (s['active_orders'] ?? 0) as int;
            _totalEarnings = ((s['total_earnings'] ?? 0) as num).toDouble();
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching home data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingHomeData = false;
        });
      }
    }
  }

  Future<void> _fetchCourierProfile() async {
    try {
      final result = await CourierProfileService.getProfile();
      if (mounted && result['success'] == true) {
        final data = result['data'];
        final name = data['name'] ?? data['user']?['name'] ?? 'Kurir';
        setState(() {
          _courierName = name;
        });
      }
    } catch (e) {
      debugPrint('Error fetching courier profile: $e');
    }
  }

  void _onStatusChange() {
    if (!mounted) return;
    final statusService = Provider.of<CourierStatusService>(context, listen: false);

    if (statusService.isWorking) {
      CourierLiveLocationService.instance.start(statusService);
      PickupRequestPollingService.instance.startPolling(context);
    } else {
      CourierLiveLocationService.instance.stop();
      PickupRequestPollingService.instance.stopPolling();
    }
  }

  Future<void> _initLocationService() async {
    final statusService = Provider.of<CourierStatusService>(context, listen: false);
    if (statusService.isWorking) {
      CourierLiveLocationService.instance.start(statusService);
    }
  }

  Future<void> _toggleOnlineStatus() async {
    final statusService = Provider.of<CourierStatusService>(context, listen: false);
    if (statusService.isLoading) return;

    final isCurrentlyOnline = statusService.isOnline;
    final newStatus = isCurrentlyOnline ? CourierStatus.offline : CourierStatus.online;

    try {
      double? lat;
      double? lng;

      if (newStatus == CourierStatus.online) {
        try {
          Position position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
          );
          lat = position.latitude;
          lng = position.longitude;
        } catch (e) {
          debugPrint('Error getting location: $e');
        }
      }

      await statusService.updateStatus(newStatus, latitude: lat, longitude: lng);

      if (mounted) {
        final success = statusService.currentStatus == newStatus;
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Status Anda sekarang ${newStatus.name}'),
              backgroundColor: newStatus == CourierStatus.online ? primaryColor : AppColors.textSecondary,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gagal memperbarui status. Silakan coba lagi.'),
              backgroundColor: AppColors.errorColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Terjadi kesalahan: $e'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _statusService?.removeListener(_onStatusChange);

    PickupRequestPollingService.instance.stopPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA), // Body bg color from HTML
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildTopHeader(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _fetchHomeData,
                color: primaryColor,
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 100),
                  children: [
                    Consumer<CourierStatusService>(
                      builder: (context, statusService, child) {
                        return _buildBanner(statusService);
                      },
                    ),
                    _buildSummary(),
                    _buildOrdersSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: DriverBottomNavigation(
        currentIndex: 0,
        onTap: (index) {
          if (index == 1) {
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
    );
  }

  Widget _buildTopHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Halo, $_courierName',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const Text(' 👋', style: TextStyle(fontSize: 18)),
                ],
              ),
              const SizedBox(height: 2),
              const Text(
                'Semangat deliveri hari ini!',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBanner(CourierStatusService statusService) {
    final bool isOnline = statusService.isOnline;
    final bool isLoading = statusService.isLoading;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      height: 160,
      decoration: BoxDecoration(
        image: const DecorationImage(
          image: AssetImage('assets/images/bg2.png'),
          fit: BoxFit.cover,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: 10,
            bottom: -5,
            child: Image.asset(
              'assets/images/Kurir1.png',
              height: 100,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const SizedBox(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text(
                  isOnline ? 'Anda Online' : 'Anda Offline',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isOnline ? greenColor : Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isOnline ? 'Siap Menerima Order' : 'Sedang Istirahat',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            right: 24,
            top: 24,
            child: GestureDetector(
              onTap: _toggleOnlineStatus,
              child: Container(
                width: 64,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFA366),
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.all(3),
                child: Stack(
                  children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      left: isOnline ? 32 : 0,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: isLoading
                            ? const Padding(
                                padding: EdgeInsets.all(4.0),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                                ),
                              )
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Ringkasan Hari Ini',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              GestureDetector(
                onTap: () {},
                child: const Row(
                  children: [
                    Text(
                      'Lihat Detail',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: primaryColor,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.chevron_right, size: 16, color: primaryColor),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  icon: Icons.inventory_2,
                  iconColor: primaryColor,
                  bgColor: const Color(0xFFFFF0E6),
                  value: '$_totalShipments',
                  label: 'Shipment\nSelesai',
                ),
              ),
              Container(width: 1, height: 40, color: const Color(0xFFF1F5F9)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: _buildStatItem(
                    icon: Icons.directions_car,
                    iconColor: greenColor,
                    bgColor: const Color(0xFFE9F9F0),
                    value: '$_activeOrders',
                    label: 'Shipment\nBerjalan',
                  ),
                ),
              ),
              Container(width: 1, height: 40, color: const Color(0xFFF1F5F9)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: _buildStatItem(
                    icon: Icons.account_balance_wallet,
                    iconColor: primaryColor,
                    bgColor: const Color(0xFFFFF0E6),
                    value: _formatRupiah(_totalEarnings),
                    label: 'Total\nPendapatan',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatRupiah(num value) {
    final grouped = value.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );
    return 'Rp $grouped';
  }

  Widget _buildStatItem({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String value,
    required String label,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: Color(0xFF64748B),
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildOrdersSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Terima Pesanan',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const DriverShipmentScreen()),
                  );
                },
                child: const Row(
                  children: [
                    Text(
                      'Lihat Semua',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: primaryColor,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.chevron_right, size: 16, color: primaryColor),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoadingHomeData && _activeOrder == null && _pendingTasks.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(color: primaryColor),
              ),
            )
          else if (_activeOrder != null)
            _buildActiveOrderSection()
          else if (_pendingTasks.isNotEmpty)
            ..._pendingTasks.map((task) => _buildPendingTaskCard(task))
          else
            _buildEmptyState(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(double.infinity, 100),
                  painter: _DottedRoutePainter(),
                ),
                Image.asset(
                  'assets/images/Box.png',
                  height: 90,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.inventory_2, size: 80, color: primaryColor),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Belum ada pesanan baru',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Jika ada pesanan masuk, akan muncul di sini.',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _fetchHomeData,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text(
                'Refresh',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveOrderSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.textWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE9F9F0),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Sedang Berjalan',
                  style: TextStyle(
                    color: greenColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _activeOrder!['tracking_number'] ?? _activeOrder!['order_number'] ?? '#${_activeOrder!['id']}',
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.primaryBlue, fontWeight: FontWeight.w800, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Middle Row: Addresses & Info
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left Column: Addresses
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      // Pickup
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF5A00),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Center(
                              child: Icon(Icons.inventory_2, color: Colors.white, size: 10),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _activeOrder!['sender_name'] ?? _activeOrder!['pickup_address'] ?? 'Lokasi Penjemputan',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _activeOrder!['pickup_address'] ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                    height: 1.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      // Dotted Line
                      Row(
                        children: [
                          Container(
                            width: 16,
                            height: 30,
                            alignment: Alignment.center,
                            child: CustomPaint(
                              size: const Size(1, 30),
                              painter: _VerticalDottedPainter(color: const Color(0xFFCBD5E1)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              height: 1,
                              margin: const EdgeInsets.symmetric(vertical: 10),
                              child: CustomPaint(
                                painter: _HorizontalDottedPainter(color: const Color(0xFFE2E8F0)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Dropoff
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(Icons.location_on, color: Color(0xFF22C55E), size: 18),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _activeOrder!['receiver_name'] ?? 'Tujuan',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _activeOrder!['dropoff_address'] ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                    height: 1.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Vertical Divider
                Container(
                  width: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  child: CustomPaint(
                    painter: _VerticalDottedPainter(color: const Color(0xFFE2E8F0)),
                  ),
                ),
                
                // Right Column: Info
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Status',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 10,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _activeOrder!['status'].toString().toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Customer',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 10,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _activeOrder!['receiver_name'] ?? 'Pelanggan',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          color: Color(0xFFFF5A00),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          // Bottom Row: Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DriverDeliveryFlowScreen(
                          order: _activeOrder!,
                        ),
                      ),
                    ).then((_) => _fetchHomeData());
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFF5A00),
                    side: const BorderSide(color: Color(0xFFFF5A00), width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(
                    'Detail',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DriverNavigationScreen(order: _activeOrder!),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5A00),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Navigasi',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPendingTaskCard(Map<String, dynamic> task) {
    String formattedPrice = 'Rp 0';
    if (task['price'] != null) {
      formattedPrice = 'Rp ${task['price']}';
    } else if (task['amount'] != null) {
      formattedPrice = 'Rp ${task['amount']}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.textWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top Row: Baru & Distance
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0E6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Baru',
                  style: TextStyle(
                    color: Color(0xFFFF5A00),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Row(
                children: [
                  Text(
                    '2.4 km',
                    style: TextStyle(
                      color: Color(0xFFFF5A00),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.location_on, color: Color(0xFFFF5A00), size: 16),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Middle Row: Addresses & Price
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left Column: Addresses
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      // Pickup
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF5A00),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Center(
                              child: Icon(Icons.inventory_2, color: Colors.white, size: 10),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  task['sender_name'] ?? task['pickup_address'] ?? 'Toko Elektronik Surabaya',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  task['pickup_address'] ?? 'Jl. Raya Darmo No. 123\nSurabaya, Jawa Timur',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                    height: 1.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      // Dotted Line
                      Row(
                        children: [
                          Container(
                            width: 16,
                            height: 30,
                            alignment: Alignment.center,
                            child: CustomPaint(
                              size: const Size(1, 30),
                              painter: _VerticalDottedPainter(color: const Color(0xFFCBD5E1)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              height: 1,
                              margin: const EdgeInsets.symmetric(vertical: 10),
                              child: CustomPaint(
                                painter: _HorizontalDottedPainter(color: const Color(0xFFE2E8F0)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Dropoff
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(Icons.location_on, color: Color(0xFF22C55E), size: 18),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  task['receiver_name'] ?? 'Budi Santoso',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  task['dropoff_address'] ?? 'Jl. Kutisari Indah No. 45\nSurabaya, Jawa Timur',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                    height: 1.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Vertical Divider
                Container(
                  width: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  child: CustomPaint(
                    painter: _VerticalDottedPainter(color: const Color(0xFFE2E8F0)),
                  ),
                ),
                
                // Right Column: Price & Info
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Estimasi',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 10,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        '20 - 30 mnt',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Harga',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 10,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formattedPrice,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: Color(0xFF22C55E),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'COD',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          // Bottom Row: Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DriverDetailShipmentScreen(shipment: task),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFF5A00),
                    side: const BorderSide(color: Color(0xFFFF5A00), width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(
                    'Lihat Detail',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DriverDetailShipmentScreen(shipment: task),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5A00),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Terima',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DottedRoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    const dashWidth = 4.0;
    const dashSpace = 4.0;
    
    final path = Path();
    path.moveTo(10, size.height / 2);
    path.quadraticBezierTo(size.width * 0.25, size.height * 0.2, size.width * 0.5, size.height / 2);
    path.quadraticBezierTo(size.width * 0.75, size.height * 0.8, size.width - 10, size.height / 2);

    for (PathMetric measurePath in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < measurePath.length) {
        canvas.drawPath(
          measurePath.extractPath(distance, distance + dashWidth),
          paint,
        );
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _VerticalDottedPainter extends CustomPainter {
  final Color color;
  _VerticalDottedPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const dashHeight = 3.0;
    const dashSpace = 3.0;
    double startY = 0;

    while (startY < size.height) {
      canvas.drawLine(Offset(size.width / 2, startY), Offset(size.width / 2, startY + dashHeight), paint);
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HorizontalDottedPainter extends CustomPainter {
  final Color color;
  _HorizontalDottedPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const dashWidth = 3.0;
    const dashSpace = 3.0;
    double startX = 0;

    while (startX < size.width) {
      canvas.drawLine(Offset(startX, size.height / 2), Offset(startX + dashWidth, size.height / 2), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
