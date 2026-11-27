import 'package:city_courierapp/core/config/app_typography.dart';
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
import 'package:flutter/services.dart';

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
  bool _hideBalance = false;
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

  void _openTransactions() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WalletTransactionsScreen(service: _service),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);
    final topInset = MediaQuery.paddingOf(context).top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: CityWalletUi.scaffoldBg(context),
        body: _loading
            ? Column(
                children: [
                  _buildOrangeHeaderStandalone(topInset, canPop),
                  const Expanded(
                    child: Center(
                      child: CircularProgressIndicator(
                        color: CityWalletUi.primaryColor,
                      ),
                    ),
                  ),
                ],
              )
            : _biometricLocked
                ? Column(
                    children: [
                      _buildOrangeHeaderStandalone(topInset, canPop),
                      Expanded(child: _buildBiometricLockState()),
                    ],
                  )
                : _error != null
                    ? Column(
                        children: [
                          _buildOrangeHeaderStandalone(topInset, canPop),
                          Expanded(
                            child: WalletErrorState(
                              message: _error!,
                              onRetry: _load,
                            ),
                          ),
                        ],
                      )
                    : RefreshIndicator(
                        color: CityWalletUi.primaryColor,
                        onRefresh: _load,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.zero,
                          children: [
                            Stack(
                              children: [
                                WalletOrangeBannerBackground(
                                  height: topInset + 206,
                                ),
                                Column(
                                  children: [
                                    SizedBox(height: topInset),
                                    _buildHeaderRow(canPop),
                                    const SizedBox(height: 8),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                      child: Column(
                                        children: [
                                          if (_wallet!.isFrozen)
                                            _buildFrozenBanner(),
                                          _buildBalanceCard(),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: _buildQuickActions(),
                            ),
                            const SizedBox(height: 16),
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 0, 16, 28),
                              child: _buildRecentTransactionsSection(),
                            ),
                          ],
                        ),
                      ),
      ),
    );
  }

  Widget _buildOrangeHeaderStandalone(double topInset, bool canPop) {
    return Stack(
      children: [
        WalletOrangeBannerBackground(height: topInset + 58),
        Column(
          children: [
            SizedBox(height: topInset),
            _buildHeaderRow(canPop),
          ],
        ),
      ],
    );
  }

  Widget _buildHeaderRow(bool canPop) {
    return SizedBox(
      height: 54,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          children: [
            if (canPop)
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 22,
                ),
                tooltip: 'Kembali',
              )
            else
              const SizedBox(width: 48),
            Expanded(
              child: Text(
                'City Wallet Saya',
                textAlign: TextAlign.center,
                style: AppTypography.titleMedium.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            IconButton(
              onPressed: _loading ? null : _load,
              icon: const Icon(
                Icons.refresh,
                color: Colors.white,
                size: 21,
              ),
              tooltip: 'Muat ulang',
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
      margin: const EdgeInsets.only(bottom: 12),
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

    return WalletFloatingBalanceCard(
      availableBalance: w.availableBalance,
      hideBalance: _hideBalance,
      onToggleHideBalance: () => setState(() => _hideBalance = !_hideBalance),
      leftStatIcon: Icons.lock_outline_rounded,
      leftStatLabel: 'Dana tertahan',
      leftStatAmount: w.reservedBalance,
      rightStatIcon: Icons.layers_outlined,
      rightStatLabel: 'Total masuk',
      rightStatAmount: w.totalCredited,
      primaryIcon: Icons.add_circle_outline,
      primaryLabel:
          w.topupProviderEnabled ? 'Top-Up Saldo' : 'Top-Up Dinonaktifkan Admin',
      onPrimaryPressed: !canTopup
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
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        _actionChip(Icons.history_rounded, 'Riwayat', _openTransactions),
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
    return WalletDashboardHistoryCard(
      onSeeAll: _openTransactions,
      isEmpty: _recentTx.isEmpty,
      emptyTitle: 'Belum ada transaksi wallet',
      emptySubtitle: 'Top-up, pembayaran, dan refund Anda akan tercatat di sini.',
      children: _recentTx
          .map(
            (tx) => WalletTxTile(
              tx: tx,
              compactDashboardStyle: true,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WalletTransactionDetailScreen(tx: tx),
                ),
              ),
            ),
          )
          .toList(),
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
