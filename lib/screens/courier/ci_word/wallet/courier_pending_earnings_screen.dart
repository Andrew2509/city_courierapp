import 'package:city_courierapp/core/utils/currency_format.dart';
import 'package:city_courierapp/models/wallet/wallet_models.dart';
import 'package:city_courierapp/screens/wallet/widgets/wallet_ui_components.dart';
import 'package:city_courierapp/services/wallet/courier_wallet_v1_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CourierPendingEarningsScreen extends StatefulWidget {
  final CourierWalletV1Service? service;

  const CourierPendingEarningsScreen({super.key, this.service});

  @override
  State<CourierPendingEarningsScreen> createState() => _CourierPendingEarningsScreenState();
}

class _CourierPendingEarningsScreenState extends State<CourierPendingEarningsScreen> {
  late final CourierWalletV1Service _service = widget.service ?? CourierWalletV1Service.instance;
  List<CourierEarningV1> _items = [];
  int _pendingTotal = 0;
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
      final res = await _service.getEarnings(status: 'pending');
      if (!mounted) return;
      setState(() {
        _pendingTotal = res.summary.pendingEarnings;
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
        title: const Text('Pending Earnings'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? WalletErrorState(message: _error!, onRetry: _load)
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFF59E0B)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Dalam Masa Tunggu Settlement',
                              style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF92400E))),
                          const SizedBox(height: 6),
                          Text(
                            formatRupiah(_pendingTotal),
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF78350F)),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Dana otomatis berpindah ke Available Earnings setelah periode konfirmasi & sengketa berakhir.',
                            style: TextStyle(fontSize: 12, color: Color(0xFF78350F)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_items.isEmpty)
                      const Center(child: Text('Tidak ada pending earnings saat ini.'))
                    else
                      ..._items.map((e) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text('Order #${e.orderId} • ${formatRupiah(e.netAmount)}',
                                  style: const TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: Text(
                                e.availableAt != null
                                    ? 'Tersedia: ${DateFormat('dd MMM yyyy, HH:mm').format(e.availableAt!.toLocal())}'
                                    : e.reference,
                              ),
                              trailing: WalletStatusChip(status: e.status),
                            ),
                          )),
                  ],
                ),
    );
  }
}
