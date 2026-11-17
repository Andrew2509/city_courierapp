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
  State<CustomerWalletDashboardScreen> createState() =>
      _CustomerWalletDashboardScreenState();
}

class _CustomerWalletDashboardScreenState
    extends State<CustomerWalletDashboardScreen> {
  late final CustomerWalletService _service =
      widget.service ?? CustomerWalletService.instance;
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
      backgroundColor: AppColors.backgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            CityWalletUi.buildHeader(
              context,
              title: 'City Wallet Saya',
              trailing: IconButton(
                onPressed: _loading ? null : _load,
                icon: const Icon(
                  Icons.refresh,
                  color: CityWalletUi.inkPrimary,
                  size: 20,
                ),
                tooltip: 'Muat ulang',
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryOrange,
                      ),
                    )
                  : _biometricLocked
                      ? _buildBiometricLockState()
                      : _error != null
                          ? WalletErrorState(message: _error!, onRetry: _load)
                          : RefreshIndicator(
                              color: AppColors.primaryOrange,
                              onRefresh: _load,
                              child: ListView(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 8, 16, 28),
                                children: [
                                  if (_wallet!.isFrozen) _buildFrozenBanner(),
                                  _buildBalanceCard(),
                                  const SizedBox(height: 16),
                                  _buildQuickActions(),
                                  const SizedBox(height: 24),
                                  _buildRecentTransactionsSection(),
                                ],
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBiometricLockState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primaryOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.fingerprint_rounded,
                color: AppColors.primaryOrange,
                size: 34,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'City Wallet Terkunci',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: CityWalletUi.inkPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _biometricHint ??
                  'Verifikasi biometrik diperlukan untuk melindungi saldo Anda.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: CityWalletUi.inkSecondary,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: 240,
              child: ElevatedButton.icon(
                onPressed: _unlockWithBiometric,
                style: CityWalletUi.primaryButtonStyle(),
                icon: const Icon(Icons.fingerprint_rounded),
                label: const Text(
                  'Buka dengan Biometrik',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFrozenBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.ac_unit_rounded, color: CityWalletUi.errorRed, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Wallet Dibekukan: ${_wallet!.freezeReason ?? "Hubungi Admin City Courier"}',
              style: const TextStyle(
                color: Color(0xFF991B1B),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard() {
    final w = _wallet!;
    final canTopup = !w.isFrozen && w.topupProviderEnabled;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: AppColors.primaryOrange,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Saldo Tersedia',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white70,
                  ),
                ),
              ),
              EnvironmentModeBadge(
                mode: w.mode,
                isSimulated: w.isSandboxOrDemo,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            formatRupiah(w.availableBalance),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: Colors.white24),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _statColumn(
                  label: 'Dana tertahan',
                  value: formatRupiah(w.reservedBalance),
                ),
              ),
              Container(width: 1, height: 28, color: Colors.white24),
              const SizedBox(width: 12),
              Expanded(
                child: _statColumn(
                  label: 'Total masuk',
                  value: formatRupiah(w.totalCredited),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton.icon(
              onPressed: !canTopup
                  ? null
                  : () async {
                      final changed = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TopupAmountScreen(
                            minAmount: w.topupMinIdr,
                            maxAmount: w.topupMaxIdr,
                            service: _service,
                          ),
                        ),
                      );
                      if (changed == true) _load();
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primaryOrange,
                disabledBackgroundColor: Colors.white24,
                disabledForegroundColor: Colors.white70,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: Text(
                w.topupProviderEnabled
                    ? 'Top-Up Saldo'
                    : 'Top-Up Dinonaktifkan Admin',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statColumn({required String label, required String value}) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label\n',
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white70,
              height: 1.4,
            ),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        _actionChip(Icons.history_rounded, 'Riwayat', () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => WalletTransactionsScreen(service: _service),
            ),
          );
        }),
        const SizedBox(width: 8),
        _actionChip(Icons.account_balance_outlined, 'Rekening', () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PayoutDestinationsScreen(service: _service),
            ),
          );
        }),
        const SizedBox(width: 8),
        _actionChip(Icons.outbond_outlined, 'Tarik Dana', () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CustomerWithdrawalScreen(
                wallet: _wallet!,
                service: _service,
              ),
            ),
          );
          _load();
        }),
        const SizedBox(width: 8),
        _actionChip(Icons.assignment_return_outlined, 'Refund', () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CustomerRefundScreen(service: _service),
            ),
          );
          _load();
        }),
      ],
    );
  }

  Widget _buildRecentTransactionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Transaksi Terbaru',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: CityWalletUi.inkPrimary,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WalletTransactionsScreen(service: _service),
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryOrange,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Lihat Semua',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_recentTx.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: CityWalletUi.borderColor),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 32,
                  color: Color(0xFFCBD5E1),
                ),
                SizedBox(height: 8),
                Text(
                  'Belum ada transaksi wallet',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: CityWalletUi.inkSecondary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Top-up, pembayaran, dan refund Anda akan tercatat di sini.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11.5, color: CityWalletUi.inkMuted),
                ),
              ],
            ),
          )
        else
          ..._recentTx.map(
            (tx) => WalletTxTile(
              tx: tx,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WalletTransactionDetailScreen(tx: tx),
                ),
              ),
            ),
          ),
      ],
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
            border: Border.all(color: CityWalletUi.borderColor),
          ),
          child: Column(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.primaryOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: AppColors.primaryOrange, size: 18),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: CityWalletUi.inkPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
