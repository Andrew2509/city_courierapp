import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:city_courierapp/core/config/app_typography.dart';
import 'package:city_courierapp/models/wallet/wallet_models.dart';
import 'package:city_courierapp/screens/courier/ci_word/home/driver_home_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/profile/driver_profile_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/shipment/driver_shipment_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/wallet/courier_withdrawal_v1_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/wallet/riwayat_transaksi_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/wallet/transaction_detail_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/wallet/widgets/wallet_history_tile.dart';
import 'package:city_courierapp/screens/courier/ci_word/wallet/widgets/wallet_notifications_sheet.dart';
import 'package:city_courierapp/screens/courier/ci_word/widgets/driver_bottom_navigation.dart';
import 'package:city_courierapp/screens/wallet/widgets/wallet_ui_components.dart';
import 'package:city_courierapp/services/security/biometric_guard_service.dart';
import 'package:city_courierapp/services/wallet/courier_wallet_v1_service.dart';
import 'package:city_courierapp/services/wallet/wallet_service.dart';

/// Dompet Kurir.
///
/// Mengadopsi tata letak dan komponen visual yang seragam dengan
/// `CustomerWalletDashboardScreen`: AppBar bersih, hero card gradasi oranye
/// dengan tombol Tarik Saldo, dan daftar transaksi terbaru.
class DompetScreen extends StatefulWidget {
  final CourierWalletV1Service? v1Service;
  final Future<Map<String, dynamic>> Function()? walletFetcher;
  final Future<Map<String, dynamic>> Function()? historyFetcher;
  final Future<Map<String, dynamic>> Function()? notificationsFetcher;

  const DompetScreen({
    super.key,
    this.v1Service,
    this.walletFetcher,
    this.historyFetcher,
    this.notificationsFetcher,
  });

  @override
  State<DompetScreen> createState() => _DompetScreenState();
}

class _DompetScreenState extends State<DompetScreen> {
  late final CourierWalletV1Service _v1Service =
      widget.v1Service ?? CourierWalletV1Service.instance;
  WalletBalance? _balance;
  CourierWalletV1Summary? _v1Summary;
  List<WalletHistoryItem> _recent = const [];
  int _notificationCount = 0;

  bool _isLoading = true;
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
      reason: 'Verifikasi sidik jari atau wajah untuk membuka Dompet Saya',
    );
    if (!mounted) return;
    setState(() {
      _biometricLocked = !res.authenticated;
      _biometricHint = res.authenticated ? null : res.message;
    });
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final v1Future = _v1Service
          .getWallet()
          .then<CourierWalletV1Summary?>((s) => s)
          .catchError((_) => null);
      final v1PayoutsFuture = widget.historyFetcher == null
          ? _v1Service
              .getPayouts(page: 1)
              .then<List<PayoutTransactionV1>?>((r) => r.items)
              .catchError((_) => null)
          : Future<List<PayoutTransactionV1>?>.value(null);
      final v1NotifFuture = widget.notificationsFetcher == null
          ? _v1Service
              .getNotifications()
              .then<List<CourierPayoutNotificationV1>?>((items) => items)
              .catchError((_) => null)
          : Future<List<CourierPayoutNotificationV1>?>.value(null);

      final results = await Future.wait([
        (widget.walletFetcher ?? WalletService.getWallet)(),
        (widget.historyFetcher ??
            () => WalletService.getHistory(page: 1, perPage: 6))(),
        (widget.notificationsFetcher ?? WalletService.getNotifications)(),
        v1Future,
        v1PayoutsFuture,
        v1NotifFuture,
      ]);

      if (!mounted) return;

      final walletResult = results[0] as Map<String, dynamic>;
      final historyResult = results[1] as Map<String, dynamic>;
      final notificationsResult = results[2] as Map<String, dynamic>;
      final v1Summary = results[3] as CourierWalletV1Summary?;
      final v1Payouts = results[4] as List<PayoutTransactionV1>?;
      final v1Notifs = results[5] as List<CourierPayoutNotificationV1>?;

      final walletOk =
          (walletResult['success'] == true && walletResult['data'] != null) ||
              v1Summary != null;
      final needsBiometric = (v1Summary?.biometricEnabled ?? false) &&
          !BiometricGuardService.isSessionUnlocked;

      final legacyRecent = historyResult['success'] == true
          ? (historyResult['items'] as List<WalletHistoryItem>)
          : const <WalletHistoryItem>[];
      final mergedRecent = v1Payouts != null
          ? WalletService.mergeHistoryWithPayouts(
              historyItems: legacyRecent,
              payouts: v1Payouts,
            ).take(6).toList()
          : legacyRecent;

      setState(() {
        _isLoading = false;
        _biometricLocked = needsBiometric;

        _balance = (walletResult['success'] == true &&
                walletResult['data'] != null)
            ? WalletBalance.fromJson(
                (walletResult['data'] as Map).cast<String, dynamic>(),
              )
            : null;
        _v1Summary = v1Summary;

        _recent = mergedRecent;

        final legacyNotifs =
            (notificationsResult['items'] as List<WalletNotificationItem>?) ??
                const [];
        final mergedNotifs = v1Notifs != null
            ? WalletService.mergeNotificationsWithPayouts(
                legacy: legacyNotifs,
                v1: v1Notifs,
              )
            : legacyNotifs;
        _notificationCount = mergedNotifs.length;

        _error = walletOk
            ? null
            : (walletResult['message']?.toString() ?? 'Gagal memuat data dompet');
      });

      if (needsBiometric) {
        await _unlockWithBiometric();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Gagal memuat data dompet';
      });
    }
  }

  Future<void> _openTarikSaldo() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CourierWithdrawalV1Screen(service: _v1Service),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _openHistory() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RiwayatTransaksiScreen(v1Service: _v1Service),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);
    final topInset = MediaQuery.paddingOf(context).top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: CityWalletUi.scaffoldBg(context),
        body: _isLoading
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
                                          if (_v1Summary?.isFrozen == true)
                                            _buildFrozenBanner(),
                                          _buildSaldoCard(),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                              child: _buildRiwayatSection(),
                            ),
                          ],
                        ),
                      ),
        bottomNavigationBar: DriverBottomNavigation(
          currentIndex: 2,
          onTap: (index) {
            if (index == 0) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (context) => const DriverHomeScreen()),
              );
            } else if (index == 1) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (context) => const DriverShipmentScreen()),
              );
            } else if (index == 3) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (context) => const DriverProfileScreen()),
              );
            }
          },
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
                'Dompet Saya',
                textAlign: TextAlign.center,
                style: AppTypography.titleMedium.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  onPressed: () => showWalletNotifications(context),
                  icon: const Icon(
                    Icons.notifications_none_rounded,
                    color: Colors.white,
                    size: 23,
                  ),
                  tooltip: 'Notifikasi',
                ),
                if (_notificationCount > 0)
                  Positioned(
                    right: 12,
                    top: 12,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFFA5A00),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
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
              'Dompet Terkunci',
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
              'Dompet Dibekukan: ${_v1Summary?.freezeReason ?? "Hubungi Admin City Courier"}',
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

  // ───────────────────────── SALDO CARD ─────────────────────────

  Widget _buildSaldoCard() {
    final balance = _balance;
    final available =
        _v1Summary?.availableBalance ?? balance?.availableBalance ?? 0;
    final pending = _v1Summary != null
        ? (_v1Summary!.reservedBalance + _v1Summary!.pendingBalance)
        : (balance?.pendingBalance ?? 0);
    final total = available + pending;
    final isFrozen = _v1Summary?.isFrozen == true;
    final canWithdraw =
        !isFrozen && (_v1Summary?.payoutProviderEnabled ?? true);

    return WalletFloatingBalanceCard(
      availableBalance: available,
      hideBalance: _hideBalance,
      onToggleHideBalance: () => setState(() => _hideBalance = !_hideBalance),
      leftStatIcon: Icons.lock_outline_rounded,
      leftStatLabel: 'Dana tertahan',
      leftStatAmount: pending,
      rightStatIcon: Icons.layers_outlined,
      rightStatLabel: 'Total saldo',
      rightStatAmount: total,
      primaryIcon: Icons.save_alt_rounded,
      primaryLabel: 'Tarik Saldo',
      onPrimaryPressed: canWithdraw ? _openTarikSaldo : null,
    );
  }

  // ───────────────────────── RIWAYAT ─────────────────────────

  Widget _buildRiwayatSection() {
    return WalletDashboardHistoryCard(
      onSeeAll: _openHistory,
      isEmpty: _recent.isEmpty,
      emptyTitle: 'Belum ada transaksi dompet',
      emptySubtitle:
          'Pendapatan pengantaran dan penarikan saldo Anda akan tercatat di sini.',
      children: _recent
          .map(
            (item) => WalletHistoryTile(
              item: item,
              compactDashboardStyle: true,
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TransactionDetailScreen(
                      item: item,
                      v1Service: _v1Service,
                    ),
                  ),
                );
                if (mounted) await _load();
              },
            ),
          )
          .toList(),
    );
  }
}
