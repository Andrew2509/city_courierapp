import 'package:city_courierapp/core/utils/currency_format.dart';
import 'package:city_courierapp/models/wallet/wallet_models.dart';
import 'package:city_courierapp/screens/courier/ci_word/wallet/courier_withdrawal_v1_screen.dart';
import 'package:city_courierapp/screens/wallet/widgets/wallet_ui_components.dart';
import 'package:city_courierapp/services/wallet/courier_wallet_v1_service.dart';
import 'package:flutter/material.dart';

class AutoPayoutStatusScreen extends StatefulWidget {
  final CourierWalletV1Service? service;

  const AutoPayoutStatusScreen({super.key, this.service});

  @override
  State<AutoPayoutStatusScreen> createState() => _AutoPayoutStatusScreenState();
}

class _AutoPayoutStatusScreenState extends State<AutoPayoutStatusScreen> {
  late final CourierWalletV1Service _service = widget.service ?? CourierWalletV1Service.instance;
  CourierAutoPayoutStatusV1? _status;
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
        _status = res.autoPayoutStatus;
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
        title: const Text('Status Auto-Payout Kurir'),
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
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: _status!.eligibleNow ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _status!.eligibleNow ? const Color(0xFF16A34A) : const Color(0xFFF59E0B),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _status!.eligibleNow ? Icons.check_circle_rounded : Icons.schedule_rounded,
                            size: 36,
                            color: _status!.eligibleNow ? const Color(0xFF15803D) : const Color(0xFFB45309),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _status!.eligibleNow
                                      ? 'Siap Dicairkan Otomatis'
                                      : 'Menunggu Syarat Auto-Payout',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Jadwal otomatis sistem: ${_status!.scheduleCron} • Min: ${formatRupiah(_status!.minPayoutIdr)}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _checkRow('Scheduler Auto-Payout Aktif', _status!.autoPayoutEnabled),
                            _checkRow(
                              'Saldo Tersedia (${formatRupiah(_status!.availableBalance)}) >= Min (${formatRupiah(_status!.minPayoutIdr)})',
                              _status!.availableBalance >= _status!.minPayoutIdr,
                            ),
                            _checkRow(
                              'Rekening / E-Wallet Default Terverifikasi',
                              _status!.defaultDestination != null && _status!.defaultDestination!.isVerified,
                            ),
                            const SizedBox(height: 12),
                            if (_status!.defaultDestination != null)
                              Text(
                                'Tujuan Default: ${_status!.defaultDestination!.channelName} (${_status!.defaultDestination!.accountNumberMasked})',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              )
                            else
                              OutlinedButton(
                                onPressed: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CourierWithdrawalV1Screen(service: _service),
                                    ),
                                  );
                                  _load();
                                },
                                child: const Text('Atur Rekening Tujuan Payout'),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (_status!.missingRequirements.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text('Catatan Belum Terpenuhi:', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      ..._status!.missingRequirements.map(
                        (msg) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text('• $msg', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                        ),
                      ),
                    ],
                  ],
                ),
    );
  }

  Widget _checkRow(String label, bool ok) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(ok ? Icons.check_circle : Icons.cancel, color: ok ? const Color(0xFF15803D) : Colors.amber.shade700, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
