import 'package:city_courierapp/core/config/app_colors.dart';
import 'package:city_courierapp/models/wallet/wallet_models.dart';
import 'package:city_courierapp/screens/courier/ci_word/wallet/add_bank_account_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/wallet/add_ewallet_account_screen.dart';
import 'package:city_courierapp/screens/wallet/widgets/wallet_ui_components.dart';
import 'package:city_courierapp/services/wallet/courier_wallet_v1_service.dart';
import 'package:flutter/material.dart';

class CourierPayoutDestinationsScreen extends StatefulWidget {
  final CourierWalletV1Service? service;

  const CourierPayoutDestinationsScreen({super.key, this.service});

  @override
  State<CourierPayoutDestinationsScreen> createState() => _CourierPayoutDestinationsScreenState();
}

class _CourierPayoutDestinationsScreenState extends State<CourierPayoutDestinationsScreen> {
  late final CourierWalletV1Service _service = widget.service ?? CourierWalletV1Service.instance;
  List<PayoutDestinationV1> _items = [];
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
      final list = await _service.getDestinations();
      if (!mounted) return;
      setState(() {
        _items = list;
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
        title: const Text('Rekening & E-Wallet Payout'),
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
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final ok = await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(builder: (_) => AddBankAccountScreen(service: _service)),
                              );
                              if (ok == true) _load();
                            },
                            icon: const Icon(Icons.account_balance),
                            label: const Text('+ Rekening Bank'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final ok = await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(builder: (_) => AddEwalletAccountScreen(service: _service)),
                              );
                              if (ok == true) _load();
                            },
                            icon: const Icon(Icons.account_balance_wallet),
                            label: const Text('+ E-Wallet'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: Center(
                          child: Text('Belum ada rekening bank atau e-wallet payout. Tambahkan minimal satu akun terverifikasi.'),
                        ),
                      )
                    else
                      ..._items.map((d) => Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            child: ListTile(
                              leading: Icon(
                                d.destinationType == 'bank' ? Icons.account_balance : Icons.account_balance_wallet,
                                color: AppColors.primaryOrange,
                              ),
                              title: Row(
                                children: [
                                  Expanded(child: Text(d.channelName, style: const TextStyle(fontWeight: FontWeight.w700))),
                                  if (d.isDefault) const WalletStatusChip(status: 'default'),
                                ],
                              ),
                              subtitle: Text('${d.accountNumberMasked} • ${d.accountHolderName}'),
                              trailing: d.isDefault
                                  ? const Icon(Icons.check_circle, color: Color(0xFF15803D))
                                  : TextButton(
                                      onPressed: () async {
                                        await _service.setDefaultDestination(d.id);
                                        _load();
                                      },
                                      child: const Text('Default'),
                                    ),
                            ),
                          )),
                  ],
                ),
    );
  }
}
