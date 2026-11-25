import 'package:flutter/material.dart';
import 'package:city_courierapp/core/config/app_typography.dart';
import 'package:city_courierapp/screens/history/unpaid_list_screen.dart';
import 'package:city_courierapp/screens/history/shipment_status_list_screen.dart';
import 'package:city_courierapp/services/shipping/shipment_service.dart';
import 'package:city_courierapp/widgets/common/city_courier_icon.dart';

class ProfileStatsGrid extends StatefulWidget {
  final Color primaryColor;
  final Color surfaceColor;
  final Color borderColor;
  final bool isDarkMode;

  const ProfileStatsGrid({
    super.key,
    required this.primaryColor,
    required this.surfaceColor,
    required this.borderColor,
    required this.isDarkMode,
  });

  @override
  State<ProfileStatsGrid> createState() => _ProfileStatsGridState();
}

class _ProfileStatsGridState extends State<ProfileStatsGrid> {
  Map<String, dynamic> _stats = {
    'pending': 0,
    'confirmed': 0,
    'assigned': 0,
    'picking_up': 0,
    'picked_up': 0,
    'delivering': 0,
    'in_transit': 0,
    'delivered': 0,
    'cancelled': 0,
  };
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    final result = await ShipmentService.getShipmentStats();
    if (mounted) {
      if (result['success'] == true) {
        setState(() {
          _stats = Map<String, dynamic>.from(result['data']);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Gagal memuat data';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final double cardWidth = ((screenWidth - 32 - 24) / 4).clamp(76.0, 96.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Lacak Pesanan',
                style: AppTypography.titleMedium.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: widget.isDarkMode
                      ? Colors.white
                      : const Color(0xFF0F172A),
                ),
              ),
              if (_isLoading)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: widget.primaryColor,
                  ),
                )
              else
                IconButton(
                  onPressed: _fetchStats,
                  icon: CityCourierCustomIcon(
                    _errorMessage != null
                        ? CourierIconKind.errorCircle
                        : CourierIconKind.refresh,
                    size: 18,
                    color: _errorMessage != null
                        ? Colors.redAccent
                        : widget.primaryColor,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.redAccent.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  const CityCourierCustomIcon(
                    CourierIconKind.errorCircle,
                    size: 16,
                    color: Colors.redAccent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: AppTypography.caption.copyWith(
                        fontSize: 11,
                        color: Colors.redAccent,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _fetchStats,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Coba Lagi',
                      style: AppTypography.caption.copyWith(
                        fontSize: 11,
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          physics: const BouncingScrollPhysics(),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatCard(
                context,
                CourierIconKind.unpaidBill,
                'Belum Bayar',
                const UnpaidListScreen(),
                _stats['pending'] ?? 0,
                cardWidth: cardWidth,
              ),
              _buildStatCard(
                context,
                CourierIconKind.confirmedOrder,
                'Dikonfirmasi',
                const ShipmentStatusListScreen(
                  status: 'confirmed,assigned',
                  title: 'Dikonfirmasi',
                ),
                (_stats['confirmed'] ?? 0) + (_stats['assigned'] ?? 0),
                cardWidth: cardWidth,
              ),
              _buildStatCard(
                context,
                CourierIconKind.pickupBox,
                'Diambil',
                const ShipmentStatusListScreen(
                  status: 'picking_up,picked_up',
                  title: 'Diambil',
                ),
                (_stats['picking_up'] ?? 0) + (_stats['picked_up'] ?? 0),
                cardWidth: cardWidth,
              ),
              _buildStatCard(
                context,
                CourierIconKind.inTransit,
                'Perjalanan',
                const ShipmentStatusListScreen(
                  status: 'delivering,in_transit',
                  title: 'Dalam Perjalanan',
                ),
                (_stats['delivering'] ?? 0) + (_stats['in_transit'] ?? 0),
                cardWidth: cardWidth,
              ),
              _buildStatCard(
                context,
                CourierIconKind.deliveredCheck,
                'Terkirim',
                const ShipmentStatusListScreen(
                  status: 'delivered',
                  title: 'Terkirim',
                ),
                _stats['delivered'] ?? 0,
                cardWidth: cardWidth,
              ),
              _buildStatCard(
                context,
                CourierIconKind.cancelledOrder,
                'Batal',
                const ShipmentStatusListScreen(
                  status: 'cancelled',
                  title: 'Dibatalkan',
                ),
                _stats['cancelled'] ?? 0,
                cardWidth: cardWidth,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    CourierIconKind iconKind,
    String label,
    Widget targetScreen,
    int count, {
    required double cardWidth,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => targetScreen),
          ).then((_) => _fetchStats());
        },
        child: SizedBox(
          width: cardWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    key: ValueKey('stat_icon_box_$label'),
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: widget.surfaceColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: widget.isDarkMode
                            ? Colors.white.withValues(alpha: 0.08)
                            : widget.borderColor.withValues(alpha: 0.75),
                        width: 1.3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: widget.isDarkMode ? 0.2 : 0.03,
                          ),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: CityCourierCustomIcon(
                        iconKind,
                        size: 38,
                      ),
                    ),
                  ),
                  if (count > 0)
                    Positioned(
                      top: -5,
                      right: -5,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: widget.surfaceColor,
                            width: 2,
                          ),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 20,
                          minHeight: 20,
                        ),
                        child: Center(
                          child: Text(
                            count > 99 ? '99+' : count.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: AppTypography.caption.copyWith(
                    fontSize: 11,
                    color: widget.isDarkMode
                        ? Colors.grey.shade300
                        : const Color(0xFF0F172A),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
