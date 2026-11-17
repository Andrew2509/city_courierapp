import 'package:city_courierapp/core/config/app_colors.dart';
import 'package:city_courierapp/core/utils/currency_format.dart';
import 'package:city_courierapp/models/wallet/wallet_models.dart';
import 'package:city_courierapp/screens/courier/ci_word/wallet/courier_available_earnings_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/wallet/courier_pending_earnings_screen.dart';
import 'package:city_courierapp/screens/wallet/widgets/wallet_ui_components.dart';
import 'package:city_courierapp/services/wallet/courier_wallet_v1_service.dart';
import 'package:flutter/material.dart';

class CourierEarningsOverviewScreen extends StatefulWidget {
  final CourierWalletV1Service? service;

  const CourierEarningsOverviewScreen({super.key, this.service});

  @override
  State<CourierEarningsOverviewScreen> createState() => _CourierEarningsOverviewScreenState();
}

class _CourierEarningsOverviewScreenState extends State<CourierEarningsOverviewScreen> {
  late final CourierWalletV1Service _service = widget.service ?? CourierWalletV1Service.instance;
  CourierEarningsSummaryV1? _summary;
  List<CourierEarningV1> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _service.getEarnings();
      if (!mounted) return;
      setState(() {
        _summary = res.summary;
        _items = res.items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pendapatan Kurir'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? WalletErrorState(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                          ),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Total Gross Pengiriman', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(
                              formatRupiah(_summary!.totalGrossEarnings),
                              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Komisi Platform (${_summary!.commissionRatePercent.toStringAsFixed(1)}%): ${formatRupiah(_summary!.totalCommissionDeducted)}',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                            Text(
                              'Masa tunggu settlement: ${_summary!.settlementWaitingMinutes} menit',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _bucketCard(
                              'Pending Earnings',
                              formatRupiah(_summary!.pendingEarnings),
                              const Color(0xFFB45309),
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CourierPendingEarningsScreen(service: _service),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _bucketCard(
                              'Available Earnings',
                              formatRupiah(_summary!.availableEarnings),
                              const Color(0xFF15803D),
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CourierAvailableEarningsScreen(service: _service),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _bucketCard(
                              'Dalam Proses Payout',
                              formatRupiah(_summary!.reservedEarnings),
                              Colors.blue.shade700,
                              null,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _bucketCard(
                              'Sudah Dicairkan',
                              formatRupiah(_summary!.paidEarnings),
                              const Color(0xFF0F172A),
                              null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Text('Riwayat Pendapatan Order', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      if (_items.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: Text('Belum ada pendapatan order tercatat.')),
                        )
                      else
                        ..._items.map((e) => Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                title: Text(
                                  'Order #${e.orderId} • Net ${formatRupiah(e.netAmount)}',
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                ),
                                subtitle: Text(
                                  'Gross ${formatRupiah(e.grossAmount)} • Komisi ${formatRupiah(e.commissionAmount)}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: WalletStatusChip(status: e.status),
                              ),
                            )),
                    ],
                  ),
                ),
    );
  }

  Widget _bucketCard(String label, String value, Color accent, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54))),
                if (onTap != null) Icon(Icons.chevron_right, size: 16, color: AppColors.primaryOrange),
              ],
            ),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: accent)),
          ],
        ),
      ),
    );
  }
}
