import 'package:city_courierapp/core/utils/currency_format.dart';
import 'package:city_courierapp/models/wallet/wallet_models.dart';
import 'package:city_courierapp/screens/courier/ci_word/wallet/auto_payout_status_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/wallet/courier_payout_detail_screen.dart';
import 'package:city_courierapp/screens/wallet/widgets/wallet_ui_components.dart';
import 'package:city_courierapp/services/wallet/courier_wallet_v1_service.dart';
import 'package:flutter/material.dart';

class CourierPayoutHistoryScreen extends StatefulWidget {
  final CourierWalletV1Service? service;

  const CourierPayoutHistoryScreen({super.key, this.service});

  @override
  State<CourierPayoutHistoryScreen> createState() => _CourierPayoutHistoryScreenState();
}

class _CourierPayoutHistoryScreenState extends State<CourierPayoutHistoryScreen> {
  late final CourierWalletV1Service _service = widget.service ?? CourierWalletV1Service.instance;
  CourierAutoPayoutStatusV1? _autoStatus;
  List<PayoutTransactionV1> _items = [];
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
      final res = await _service.getPayouts();
      if (!mounted) return;
      setState(() {
        _autoStatus = res.autoPayoutStatus;
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
        title: const Text('Riwayat Payout Kurir'),
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
                      if (_autoStatus != null)
                        Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          child: ListTile(
                            leading: Icon(
                              _autoStatus!.eligibleNow ? Icons.autorenew : Icons.info_outline,
                              color: _autoStatus!.eligibleNow ? const Color(0xFF15803D) : Colors.amber.shade800,
                            ),
                            title: Text(
                              _autoStatus!.eligibleNow ? 'Auto-Payout Siap Berjalan' : 'Auto-Payout Menunggu Syarat',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                            subtitle: Text('Available: ${formatRupiah(_autoStatus!.availableBalance)}'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => AutoPayoutStatusScreen(service: _service)),
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      if (_items.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 40),
                          child: Center(child: Text('Belum ada riwayat payout otomatis.')),
                        )
                      else
                        ..._items.map((p) => Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              child: ListTile(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CourierPayoutDetailScreen(payoutId: p.id, service: _service),
                                  ),
                                ),
                                title: Text(formatRupiah(p.netAmount), style: const TextStyle(fontWeight: FontWeight.w800)),
                                subtitle: Text('${p.channelCode} • ${p.accountNumberMasked}\n${p.reference}'),
                                trailing: WalletStatusChip(status: p.status),
                              ),
                            )),
                    ],
                  ),
                ),
    );
  }
}
