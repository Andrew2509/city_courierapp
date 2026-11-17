import 'package:city_courierapp/core/config/app_colors.dart';
import 'package:city_courierapp/core/utils/currency_format.dart';
import 'package:city_courierapp/models/wallet/wallet_models.dart';
import 'package:city_courierapp/screens/wallet/payout_destinations_screen.dart';
import 'package:city_courierapp/screens/wallet/widgets/wallet_ui_components.dart';
import 'package:city_courierapp/services/wallet/customer_wallet_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomerWithdrawalScreen extends StatefulWidget {
  final CustomerWalletSummary wallet;
  final CustomerWalletService? service;

  const CustomerWithdrawalScreen({
    super.key,
    required this.wallet,
    this.service,
  });

  @override
  State<CustomerWithdrawalScreen> createState() => _CustomerWithdrawalScreenState();
}

class _CustomerWithdrawalScreenState extends State<CustomerWithdrawalScreen> {
  late final CustomerWalletService _service = widget.service ?? CustomerWalletService.instance;
  final TextEditingController _amountCtrl = TextEditingController();
  List<PayoutDestinationV1> _destinations = [];
  List<PayoutTransactionV1> _history = [];
  PayoutDestinationV1? _selectedDest;
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _service.getDestinations(),
        _service.getWithdrawals(),
      ]);
      if (!mounted) return;
      final dests = results[0] as List<PayoutDestinationV1>;
      setState(() {
        _destinations = dests;
        _selectedDest = dests.isNotEmpty
            ? dests.firstWhere((d) => d.isDefault, orElse: () => dests.first)
            : null;
        _history = results[1] as List<PayoutTransactionV1>;
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

  Future<void> _submit() async {
    final dest = _selectedDest;
    final amount = int.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (dest == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tambahkan rekening/e-wallet tujuan terlebih dahulu.')),
      );
      return;
    }
    if (amount < widget.wallet.withdrawalMinIdr || amount > widget.wallet.availableBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Nominal harus minimal ${formatRupiah(widget.wallet.withdrawalMinIdr)} dan tidak melebihi saldo tersedia.',
          ),
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await _service.requestWithdrawal(amount: amount, destinationId: dest.id);
      if (!mounted) return;
      _amountCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permintaan penarikan dana berhasil dikirim.'), backgroundColor: Colors.green),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = !widget.wallet.withdrawalEnabled;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Penarikan Saldo Pelanggan'),
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
                    if (locked)
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFF59E0B)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.lock_outline_rounded, color: Color(0xFFB45309)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Fitur Penarikan Terkunci di Production',
                                    style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF92400E)),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.wallet.withdrawalBlockedReason ??
                                        'Penarikan wallet pelanggan menunggu persetujuan regulasi & penyedia pembayaran.',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF78350F)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Saldo Tersedia: ${formatRupiah(widget.wallet.availableBalance)}',
                                  style: const TextStyle(fontWeight: FontWeight.w700)),
                              EnvironmentModeBadge(mode: widget.wallet.mode),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _amountCtrl,
                            enabled: !locked,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: const InputDecoration(
                              labelText: 'Nominal Penarikan (IDR)',
                              prefixText: 'Rp ',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_destinations.isEmpty)
                            OutlinedButton.icon(
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => PayoutDestinationsScreen(service: _service)),
                                );
                                _load();
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Tambah Rekening / E-Wallet'),
                            )
                          else
                            DropdownButtonFormField<int>(
                              initialValue: _selectedDest?.id,
                              decoration: const InputDecoration(
                                labelText: 'Rekening Tujuan',
                                border: OutlineInputBorder(),
                              ),
                              items: _destinations
                                  .map((d) => DropdownMenuItem(
                                        value: d.id,
                                        child: Text('${d.channelName} • ${d.accountNumberMasked}'),
                                      ))
                                  .toList(),
                              onChanged: locked
                                  ? null
                                  : (id) => setState(() {
                                        _selectedDest = _destinations.firstWhere((d) => d.id == id);
                                      }),
                            ),
                          const SizedBox(height: 14),
                          ElevatedButton(
                            onPressed: (locked || _submitting) ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryOrange,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(48),
                            ),
                            child: _submitting
                                ? const CircularProgressIndicator(color: Colors.white)
                                : Text(locked ? 'Tidak Tersedia di Production' : 'Ajukan Penarikan'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('Riwayat Penarikan', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    if (_history.isEmpty)
                      const Text('Belum ada riwayat penarikan.', style: TextStyle(color: Colors.black54))
                    else
                      ..._history.map((w) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(formatRupiah(w.amount), style: const TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: Text('${w.channelCode} • ${w.accountNumberMasked}\n${w.reference}'),
                              trailing: WalletStatusChip(status: w.status),
                            ),
                          )),
                  ],
                ),
    );
  }
}
