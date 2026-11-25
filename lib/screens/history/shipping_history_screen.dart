import 'package:city_courierapp/core/config/app_typography.dart';
import 'package:city_courierapp/core/utils/auth_guard.dart';
import 'package:city_courierapp/models/shipping/shipment_model.dart';
import 'package:city_courierapp/screens/home/tracking/tracking_detail_screen.dart';
import 'package:city_courierapp/screens/widgets/history/shipping_card_widget.dart';
import 'package:city_courierapp/screens/widgets/home/bottom_nav_bar.dart';
import 'package:city_courierapp/services/shipping/shipment_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
    final isAuthed = await AuthGuard.guardScreen(context);
    if (!isAuthed) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Ambil pengiriman aktif (selain delivered dan cancelled)
      final activeResult = await ShipmentService.getUserShipments(
        status: 'pending,confirmed,assigned,picking_up,picked_up,delivering,in_transit',
      );

      // Ambil pengiriman selesai
      final completedResult = await ShipmentService.getUserShipments(
        status: 'delivered',
      );

      if (mounted) {
        if (activeResult['success'] == true &&
            completedResult['success'] == true) {
          setState(() {
            _activeShipments = activeResult['data'] as List<ShipmentModel>;
            _completedShipments =
                completedResult['data'] as List<ShipmentModel>;
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = activeResult['message'] ??
                completedResult['message'] ??
                'Gagal memuat data';
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
    const primaryColor = Color(0xFFEC5B13);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg =
        isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF9FAFB);
    final surfaceBg = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final inkPrimary = isDarkMode ? Colors.white : const Color(0xFF0F172A);
    final inkSecondary =
        isDarkMode ? Colors.grey.shade400 : const Color(0xFF64748B);
    final borderColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE2E8F0);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
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
            'Riwayat Pengiriman',
            style: AppTypography.titleMedium.copyWith(
              color: inkPrimary,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          bottom: TabBar(
            indicatorColor: primaryColor,
            indicatorWeight: 2.5,
            labelColor: primaryColor,
            unselectedLabelColor: inkSecondary,
            labelStyle: AppTypography.titleSmall.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 13.5,
            ),
            unselectedLabelStyle: AppTypography.titleSmall.copyWith(
              fontWeight: FontWeight.w500,
              fontSize: 13.5,
            ),
            dividerColor: borderColor,
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
                  // Filter Pencarian No. Resi
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: TextField(
                      controller: searchController,
                      style: AppTypography.bodySmall.copyWith(
                        fontSize: 14,
                        color: inkPrimary,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: surfaceBg,
                        hintText: 'Cari No. Resi...',
                        hintStyle: AppTypography.bodySmall.copyWith(
                          color: isDarkMode
                              ? Colors.grey.shade500
                              : const Color(0xFF94A3B8),
                          fontSize: 13.5,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: Color(0xFF94A3B8),
                          size: 20,
                        ),
                        suffixIcon: searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: Color(0xFF94A3B8),
                                  size: 18,
                                ),
                                onPressed: () {
                                  searchController.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: primaryColor,
                            width: 1.5,
                          ),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  Expanded(
                    child: _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: primaryColor,
                            ),
                          )
                        : _errorMessage != null
                            ? _buildErrorView(primaryColor, inkSecondary)
                            : TabBarView(
                                children: [
                                  _buildShipmentList(
                                    _filterShipments(_activeShipments),
                                    primaryColor,
                                    isDarkMode,
                                  ),
                                  _buildShipmentList(
                                    _filterShipments(_completedShipments),
                                    primaryColor,
                                    isDarkMode,
                                  ),
                                ],
                              ),
                  ),
                ],
              ),
              const BottomNavBar(activeIndex: 1),
            ],
          ),
        ),
      ),
    );
  }

  List<ShipmentModel> _filterShipments(List<ShipmentModel> list) {
    final query = searchController.text.toLowerCase();
    if (query.isEmpty) return list;
    return list
        .where(
          (s) => (s.trackingNumber ?? s.orderNumber)
              .toLowerCase()
              .contains(query),
        )
        .toList();
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
              onPressed: _fetchData,
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

  Widget _buildShipmentList(
    List<ShipmentModel> shipments,
    Color primaryColor,
    bool isDarkMode,
  ) {
    final inkSecondary =
        isDarkMode ? Colors.grey.shade400 : const Color(0xFF64748B);

    if (shipments.isEmpty) {
      return ListView(
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.18),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history_rounded,
                    size: 64,
                    color: isDarkMode ? Colors.white12 : const Color(0xFFCBD5E1),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Belum ada riwayat',
                    style: AppTypography.titleSmall.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDarkMode
                          ? Colors.white70
                          : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pengiriman aktif dan selesai Anda akan muncul di sini.',
                    textAlign: TextAlign.center,
                    style: AppTypography.caption.copyWith(
                      fontSize: 12.5,
                      color: inkSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 104),
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
