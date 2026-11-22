import 'package:city_courierapp/core/config/app_typography.dart';
import 'package:city_courierapp/core/utils/currency_format.dart';
import 'package:city_courierapp/models/wallet/wallet_models.dart';
import 'package:city_courierapp/screens/wallet/customer_refund_screen.dart';
import 'package:city_courierapp/screens/wallet/customer_withdrawal_screen.dart';
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
      backgroundColor: CityWalletUi.scaffoldBg(context),
      appBar: CityWalletUi.buildAppBar(
        context,
        title: 'City Wallet Saya',
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: Icon(
              Icons.refresh,
              color: CityWalletUi.ink(context),
              size: 20,
            ),
            tooltip: 'Muat ulang',
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: CityWalletUi.primaryColor,
              ),
            )
          : _biometricLocked
              ? _buildBiometricLockState()
              : _error != null
                  ? WalletErrorState(message: _error!, onRetry: _load)
                  : RefreshIndicator(
                      color: CityWalletUi.primaryColor,
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
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
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: CityWalletUi.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.fingerprint_rounded,
                color: CityWalletUi.primaryColor,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'City Wallet Terkunci',
              style: AppTypography.titleMedium.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: CityWalletUi.ink(context),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _biometricHint ??
                  'Verifikasi biometrik diperlukan untuk melindungi saldo Anda.',
              textAlign: TextAlign.center,
              style: CityWalletUi.bodyStyle(context),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 240,
              child: ElevatedButton.icon(
                onPressed: _unlockWithBiometric,
                style: CityWalletUi.primaryButtonStyle(context: context),
                icon: const Icon(Icons.fingerprint_rounded),
                label: const Text('Buka dengan Biometrik'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFrozenBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.ac_unit_rounded,
            color: CityWalletUi.errorRed,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Wallet Dibekukan: ${_wallet!.freezeReason ?? "Hubungi Admin City Courier"}',
              style: AppTypography.caption.copyWith(
                color: const Color(0xFF991B1B),
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
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: CityWalletUi.heroCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Saldo Tersedia',
                  style: AppTypography.caption.copyWith(
                    fontSize: 12.5,
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
          const SizedBox(height: 6),
          Text(
            formatRupiah(w.availableBalance),
            style: AppTypography.headline1.copyWith(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
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
            height: 46,
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
                            currentBalance: w.availableBalance,
                            service: _service,
                          ),
                        ),
                      );
                      if (changed == true) _load();
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: CityWalletUi.primaryColor,
                disabledBackgroundColor: Colors.white.withValues(alpha: 0.24),
                disabledForegroundColor: Colors.white70,
                elevation: 0,
                textStyle: AppTypography.titleSmall.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: Text(
                w.topupProviderEnabled
                    ? 'Top-Up Saldo'
                    : 'Top-Up Dinonaktifkan Admin',
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
            style: AppTypography.caption.copyWith(
              fontSize: 11.5,
              color: Colors.white70,
              height: 1.4,
            ),
          ),
          TextSpan(
            text: value,
            style: AppTypography.titleSmall.copyWith(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
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
        const SizedBox(width: 10),
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
        const SizedBox(width: 10),
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
            Expanded(
              child: Text(
                'Transaksi Terbaru',
                style: CityWalletUi.sectionTitleStyle(context),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WalletTransactionsScreen(service: _service),
                ),
              ),
              style: CityWalletUi.textButtonStyle,
              child: const Text('Lihat Semua'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_recentTx.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
            decoration: CityWalletUi.cardDecoration(context, radius: 16),
            child: Column(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 36,
                  color: CityWalletUi.mutedInk(context),
                ),
                const SizedBox(height: 8),
                Text(
                  'Belum ada transaksi wallet',
                  style: CityWalletUi.cardTitleStyle(context).copyWith(
                    fontSize: 13.5,
                    color: CityWalletUi.secondaryInk(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Top-up, pembayaran, dan refund Anda akan tercatat di sini.',
                  textAlign: TextAlign.center,
                  style: CityWalletUi.captionStyle(context),
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
      child: Container(
        decoration: CityWalletUi.cardDecoration(context, radius: 16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              child: Column(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: CityWalletUi.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      color: CityWalletUi.primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: CityWalletUi.ink(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
