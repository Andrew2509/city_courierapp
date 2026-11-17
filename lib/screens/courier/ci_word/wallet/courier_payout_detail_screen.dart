import 'package:city_courierapp/core/utils/currency_format.dart';
import 'package:city_courierapp/models/wallet/wallet_models.dart';
import 'package:city_courierapp/screens/wallet/widgets/wallet_ui_components.dart';
import 'package:city_courierapp/services/wallet/courier_wallet_v1_service.dart';
import 'package:flutter/material.dart';

class CourierPayoutDetailScreen extends StatefulWidget {
  final int payoutId;
  final CourierWalletV1Service? service;

  const CourierPayoutDetailScreen({
    super.key,
    required this.payoutId,
    this.service,
  });

  @override
  State<CourierPayoutDetailScreen> createState() => _CourierPayoutDetailScreenState();
}

class _CourierPayoutDetailScreenState extends State<CourierPayoutDetailScreen> {
  late final CourierWalletV1Service _service = widget.service ?? CourierWalletV1Service.instance;
  PayoutTransactionV1? _payout;
  List<CourierEarningV1> _earnings = [];
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
      final res = await _service.getPayoutDetail(widget.payoutId);
      if (!mounted) return;
      setState(() {
        _payout = res.payout;
        _earnings = res.earnings;
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
        title: const Text('Detail Payout Kurir'),
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
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          WalletStatusChip(status: _payout!.status),
                          const SizedBox(height: 10),
                          Text(formatRupiah(_payout!.netAmount),
                              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          Text('${_payout!.channelCode} • ${_payout!.accountNumberMasked}'),
                          Text(_payout!.accountHolderName, style: const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 10),
                          EnvironmentModeBadge(mode: _payout!.mode, isSimulated: _payout!.isSimulated),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_payout!.failureReason != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('Alasan Gagal: ${_payout!.failureReason}',
                            style: const TextStyle(color: Color(0xFF991B1B))),
                      ),
                    const Text('Riwayat Status', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    ..._payout!.statusHistory.map((item) => Card(
                          margin: const EdgeInsets.only(bottom: 6),
                          child: ListTile(
                            dense: true,
                            leading: WalletStatusChip(status: (item['status'] ?? '').toString()),
                            title: Text((item['note'] ?? '').toString()),
                            subtitle: Text((item['at'] ?? '').toString(), style: const TextStyle(fontSize: 11)),
                          ),
                        )),
                    const SizedBox(height: 16),
                    Text('Order Tercakup (${_earnings.length})',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    ..._earnings.map((e) => Card(
                          margin: const EdgeInsets.only(bottom: 6),
                          child: ListTile(
                            dense: true,
                            title: Text('Order #${e.orderId}'),
                            trailing: Text(formatRupiah(e.netAmount), style: const TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        )),
                  ],
                ),
    );
  }
}
