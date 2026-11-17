import 'package:city_courierapp/core/utils/currency_format.dart';
import 'package:city_courierapp/models/wallet/wallet_models.dart';
import 'package:city_courierapp/screens/wallet/widgets/wallet_ui_components.dart';
import 'package:city_courierapp/services/wallet/courier_wallet_v1_service.dart';
import 'package:flutter/material.dart';

class CourierAvailableEarningsScreen extends StatefulWidget {
  final CourierWalletV1Service? service;

  const CourierAvailableEarningsScreen({super.key, this.service});

  @override
  State<CourierAvailableEarningsScreen> createState() => _CourierAvailableEarningsScreenState();
}

class _CourierAvailableEarningsScreenState extends State<CourierAvailableEarningsScreen> {
  late final CourierWalletV1Service _service = widget.service ?? CourierWalletV1Service.instance;
  List<CourierEarningV1> _items = [];
  int _availableTotal = 0;
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
      final res = await _service.getEarnings(status: 'available');
      if (!mounted) return;
      setState(() {
        _availableTotal = res.summary.availableEarnings;
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
        title: const Text('Available Earnings'),
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
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF16A34A)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Siap untuk Payout Otomatis',
                              style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF166534))),
                          const SizedBox(height: 6),
                          Text(
                            formatRupiah(_availableTotal),
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF14532D)),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Dicairkan otomatis sesuai jadwal ketika memenuhi minimum payout & rekening default terverifikasi.',
                            style: TextStyle(fontSize: 12, color: Color(0xFF166534)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_items.isEmpty)
                      const Center(child: Text('Belum ada available earnings menunggu payout.'))
                    else
                      ..._items.map((e) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text('Order #${e.orderId} • ${formatRupiah(e.netAmount)}',
                                  style: const TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: Text(e.reference),
                              trailing: WalletStatusChip(status: e.status),
                            ),
                          )),
                  ],
                ),
    );
  }
}
