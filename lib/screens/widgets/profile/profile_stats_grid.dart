import 'package:flutter/material.dart';
import 'package:city_courierapp/screens/history/unpaid_list_screen.dart';
import 'package:city_courierapp/screens/history/shipment_status_list_screen.dart';
import 'package:city_courierapp/services/shipping/shipment_service.dart';

class ProfileStatsGrid extends StatefulWidget {
  final Color primaryColor;
  final Color surfaceColor;
  final Color borderColor;
  final bool isDarkMode;

  const ProfileStatsGrid({
    Key? key,
    required this.primaryColor,
    required this.surfaceColor,
    required this.borderColor,
    required this.isDarkMode,
  }) : super(key: key);

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Lacak Pesanan',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: widget.isDarkMode ? Colors.white70 : Colors.blueGrey[800],
                ),
              ),
              if (_isLoading)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                IconButton(
                  onPressed: _fetchStats,
                  icon: Icon(
                    _errorMessage != null ? Icons.error_outline : Icons.refresh_rounded,
                    size: 16,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                  color: _errorMessage != null
                      ? Colors.redAccent
                      : widget.primaryColor.withOpacity(0.5),
                ),
            ],
          ),
        ),
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, size: 16, color: Colors.redAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
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
                      style: TextStyle(
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
          padding: const EdgeInsets.symmetric(horizontal: 20),
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _buildStatCard(
                context,
                Icons.account_balance_wallet_rounded,
                'Belum Bayar',
                const UnpaidListScreen(),
                _stats['pending'] ?? 0,
              ),
              _buildStatCard(
                context,
                Icons.assignment_turned_in_rounded,
                'Dikonfirmasi',
                const ShipmentStatusListScreen(
                  status: 'confirmed,assigned',
                  title: 'Dikonfirmasi',
                ),
                (_stats['confirmed'] ?? 0) + (_stats['assigned'] ?? 0),
              ),
              _buildStatCard(
                context,
                Icons.inventory_rounded,
                'Diambil',
                const ShipmentStatusListScreen(
                  status: 'picking_up,picked_up',
                  title: 'Diambil',
                ),
                (_stats['picking_up'] ?? 0) + (_stats['picked_up'] ?? 0),
              ),
              _buildStatCard(
                context,
                Icons.local_shipping_rounded,
                'Perjalanan',
                const ShipmentStatusListScreen(
                  status: 'delivering,in_transit',
                  title: 'Dalam Perjalanan',
                ),
                (_stats['delivering'] ?? 0) + (_stats['in_transit'] ?? 0),
              ),
              _buildStatCard(
                context,
                Icons.check_circle_rounded,
                'Terkirim',
                const ShipmentStatusListScreen(
                  status: 'delivered',
                  title: 'Terkirim',
                ),
                _stats['delivered'] ?? 0,
              ),
              _buildStatCard(
                context,
                Icons.cancel_rounded,
                'Batal',
                const ShipmentStatusListScreen(
                  status: 'cancelled',
                  title: 'Dibatalkan',
                ),
                _stats['cancelled'] ?? 0,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(BuildContext context, IconData icon, String label, Widget targetScreen, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => targetScreen),
            ).then((_) => _fetchStats()); // Refresh when coming back
          },
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 80,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: widget.surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: widget.borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: widget.primaryColor.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: widget.primaryColor, size: 20),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9,
                        color: widget.isDarkMode ? Colors.white70 : Colors.blueGrey[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
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
                      border: Border.all(color: widget.surfaceColor, width: 2),
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
        ),
      ),
    );
  }
}
