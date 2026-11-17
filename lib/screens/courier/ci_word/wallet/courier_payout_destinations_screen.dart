import 'package:city_courierapp/core/config/app_colors.dart';
import 'package:city_courierapp/models/wallet/wallet_models.dart';
import 'package:city_courierapp/screens/courier/ci_word/wallet/add_bank_account_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/wallet/add_ewallet_account_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/wallet/widgets/courier_wallet_ui.dart';
import 'package:city_courierapp/screens/wallet/widgets/wallet_ui_components.dart';
import 'package:city_courierapp/services/wallet/courier_wallet_v1_service.dart';
import 'package:flutter/material.dart';

class CourierPayoutDestinationsScreen extends StatefulWidget {
  final CourierWalletV1Service? service;

  const CourierPayoutDestinationsScreen({super.key, this.service});

  @override
  State<CourierPayoutDestinationsScreen> createState() =>
      _CourierPayoutDestinationsScreenState();
}

class _CourierPayoutDestinationsScreenState
    extends State<CourierPayoutDestinationsScreen> {
  late final CourierWalletV1Service _service =
      widget.service ?? CourierWalletV1Service.instance;
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

  Future<void> _openAddBank() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AddBankAccountScreen(service: _service)),
    );
    if (ok == true && mounted) await _load();
  }

  Future<void> _openAddEwallet() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AddEwalletAccountScreen(service: _service)),
    );
    if (ok == true && mounted) await _load();
  }

  Future<void> _setDefault(PayoutDestinationV1 dest) async {
    try {
      await _service.setDefaultDestination(dest.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${dest.channelName} dijadikan rekening utama.'),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: CourierWalletUi.errorRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            CourierWalletUi.buildHeader(
              context,
              title: 'Rekening & E-Wallet',
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.primaryOrange),
                    )
                  : _error != null
                      ? WalletErrorState(message: _error!, onRetry: _load)
                      : RefreshIndicator(
                          color: AppColors.primaryOrange,
                          onRefresh: _load,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            children: [
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryOrange.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.primaryOrange.withValues(alpha: 0.25),
                                  ),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.verified_user_outlined,
                                      size: 20,
                                      color: AppColors.primaryOrange,
                                    ),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Pilih rekening utama atau tambahkan akun tujuan baru untuk pencairan saldo.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: CourierWalletUi.inkPrimary,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              if (_items.isEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 36,
                                    horizontal: 20,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: CourierWalletUi.borderColor),
                                  ),
                                  child: const Column(
                                    children: [
                                      Icon(
                                        Icons.account_balance_wallet_outlined,
                                        size: 38,
                                        color: Color(0xFFCBD5E1),
                                      ),
                                      SizedBox(height: 10),
                                      Text(
                                        'Belum ada rekening tersimpan',
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                          color: CourierWalletUi.inkPrimary,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Tambahkan minimal satu rekening bank atau akun e-wallet melalui tombol di bawah.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: CourierWalletUi.inkSecondary,
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else ...[
                                const Text(
                                  'Daftar Rekening Tujuan',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: CourierWalletUi.inkPrimary,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                ..._items.map(_buildDestinationCard),
                              ],
                            ],
                          ),
                        ),
            ),
            if (!_loading && _error == null)
              CourierWalletUi.stickyBottomBar(
                context,
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _openAddBank,
                        style: CourierWalletUi.secondaryButtonStyle(
                          borderTint: AppColors.primaryOrange.withValues(alpha: 0.45),
                          fgColor: AppColors.primaryOrange,
                        ),
                        icon: const Icon(Icons.account_balance_outlined, size: 18),
                        label: const Text(
                          '+ Rekening Bank',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _openAddEwallet,
                        style: CourierWalletUi.primaryButtonStyle(),
                        icon: const Icon(Icons.account_balance_wallet_outlined, size: 18),
                        label: const Text(
                          '+ E-Wallet',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDestinationCard(PayoutDestinationV1 d) {
    final isBank = d.destinationType == 'bank';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: d.isDefault
              ? AppColors.primaryOrange
              : CourierWalletUi.borderColor,
          width: d.isDefault ? 1.4 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isBank
                  ? AppColors.primaryOrange.withValues(alpha: 0.1)
                  : const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isBank
                  ? Icons.account_balance_outlined
                  : Icons.account_balance_wallet_outlined,
              size: 20,
              color: isBank ? AppColors.primaryOrange : const Color(0xFF15803D),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        d.channelName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: CourierWalletUi.inkPrimary,
                        ),
                      ),
                    ),
                    if (d.isDefault) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryOrange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Utama',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryOrange,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${d.accountNumberMasked} • ${d.accountHolderName}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: CourierWalletUi.inkSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (d.isDefault)
            const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF16A34A),
              size: 22,
            )
          else
            TextButton(
              onPressed: () => _setDefault(d),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryOrange,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: AppColors.primaryOrange.withValues(alpha: 0.35),
                  ),
                ),
              ),
              child: const Text(
                'Default',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}
