import 'package:city_courierapp/core/config/app_colors.dart';
import 'package:city_courierapp/core/utils/currency_format.dart';
import 'package:city_courierapp/models/wallet/wallet_models.dart';
import 'package:city_courierapp/screens/wallet/customer_refund_screen.dart';
import 'package:city_courierapp/screens/wallet/customer_withdrawal_screen.dart';
import 'package:city_courierapp/screens/wallet/payout_destinations_screen.dart';
import 'package:city_courierapp/screens/wallet/topup_amount_screen.dart';
import 'package:city_courierapp/screens/wallet/wallet_transaction_detail_screen.dart';
import 'package:city_courierapp/screens/wallet/wallet_transactions_screen.dart';
import 'package:city_courierapp/screens/wallet/widgets/wallet_ui_components.dart';
import 'package:city_courierapp/services/security/biometric_guard_service.dart';
import 'package:city_courierapp/services/wallet/customer_wallet_service.dart';
import 'package:flutter/material.dart';

class CustomerWalletDashboardScreen extends StatefulWidget {
  final CustomerWalletService? service;

  const CustomerWalletDashboardScreen({super.key, this.service});

  @override
  State<CustomerWalletDashboardScreen> createState() => _CustomerWalletDashboardScreenState();
}

class _CustomerWalletDashboardScreenState extends State<CustomerWalletDashboardScreen> {
  late final CustomerWalletService _service = widget.service ?? CustomerWalletService.instance;
  CustomerWalletSummary? _wallet;
  List<WalletTransactionV1> _recentTx = [];
  bool _loading = true;
  bool _biometricLocked = false;
  String? _biometricHint;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _unlockWithBiometric() async {
    final res = await BiometricGuardService.authenticate(
      reason: 'Verifikasi sidik jari atau wajah untuk membuka City Wallet',
    );
    if (!mounted) return;
    setState(() {
      _biometricLocked = !res.authenticated;
      _biometricHint = res.authenticated ? null : res.message;
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final walletFuture = _service.getWallet();
      final txFuture = _service.getTransactions(page: 1, perPage: 6);
      final wallet = await walletFuture;
      final txPage = await txFuture;
      final needsBiometric =
          wallet.biometricEnabled && !BiometricGuardService.isSessionUnlocked;

      if (!mounted) return;
      setState(() {
        _wallet = wallet;
        _recentTx = txPage.items;
        _loading = false;
        _biometricLocked = needsBiometric;
      });

      if (needsBiometric) {
        await _unlockWithBiometric();
      }
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
        title: const Text('City Wallet Saya'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _biometricLocked
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(
                            Icons.fingerprint_rounded,
                            color: Color(0xFF2563EB),
                            size: 34,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'City Wallet Terkunci',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _biometricHint ??
                              'Verifikasi biometrik diperlukan untuk melindungi saldo Anda.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 18),
                        ElevatedButton.icon(
                          onPressed: _unlockWithBiometric,
                          icon: const Icon(Icons.fingerprint_rounded),
                          label: const Text('Buka dengan Biometrik'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEC5B13),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : _error != null
              ? WalletErrorState(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_wallet!.isFrozen)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.shade300),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.ac_unit, color: Colors.red),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Wallet Dibekukan: ${_wallet!.freezeReason ?? "Hubungi Admin City Courier"}',
                                  style: const TextStyle(color: Color(0xFF991B1B), fontWeight: FontWeight.w600, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Saldo Tersedia', style: TextStyle(color: Colors.white70, fontSize: 13)),
                                EnvironmentModeBadge(mode: _wallet!.mode, isSimulated: _wallet!.isSandboxOrDemo),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              formatRupiah(_wallet!.availableBalance),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Text(
                                  'Tertahan: ${formatRupiah(_wallet!.reservedBalance)}',
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  'Total Masuk: ${formatRupiah(_wallet!.totalCredited)}',
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: (_wallet!.isFrozen || !_wallet!.topupProviderEnabled)
                                    ? null
                                    : () async {
                                        final changed = await Navigator.push<bool>(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => TopupAmountScreen(
                                              minAmount: _wallet!.topupMinIdr,
                                              maxAmount: _wallet!.topupMaxIdr,
                                              service: _service,
                                            ),
                                          ),
                                        );
                                        if (changed == true) _load();
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryOrange,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: Colors.white24,
                                  disabledForegroundColor: Colors.white60,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                icon: const Icon(Icons.add_circle_outline),
                                label: Text(
                                  _wallet!.topupProviderEnabled
                                      ? 'Top-Up Saldo'
                                      : 'Top-Up Dinonaktifkan Admin',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _actionChip(Icons.history_rounded, 'Riwayat', () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => WalletTransactionsScreen(service: _service)),
                            );
                          }),
                          const SizedBox(width: 8),
                          _actionChip(Icons.account_balance_rounded, 'Rekening', () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => PayoutDestinationsScreen(service: _service)),
                            );
                          }),
                          const SizedBox(width: 8),
                          _actionChip(Icons.outbond_outlined, 'Tarik Dana', () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CustomerWithdrawalScreen(wallet: _wallet!, service: _service),
                              ),
                            );
                            _load();
                          }),
                          const SizedBox(width: 8),
                          _actionChip(Icons.assignment_return_outlined, 'Refund', () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => CustomerRefundScreen(service: _service)),
                            );
                            _load();
                          }),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Transaksi Terbaru', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                          TextButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => WalletTransactionsScreen(service: _service)),
                            ),
                            child: const Text('Lihat Semua'),
                          ),
                        ],
                      ),
                      if (_recentTx.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Center(child: Text('Belum ada transaksi wallet.')),
                        )
                      else
                        ..._recentTx.map(
                          (tx) => WalletTxTile(
                            tx: tx,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => WalletTransactionDetailScreen(tx: tx)),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }

  Widget _actionChip(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              Icon(icon, color: AppColors.primaryOrange, size: 22),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
