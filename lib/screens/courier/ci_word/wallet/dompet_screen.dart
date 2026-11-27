import 'package:flutter/material.dart';

import 'package:city_courierapp/core/config/app_typography.dart';
import 'package:city_courierapp/core/utils/currency_format.dart';
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
/// dengan tombol Tarik Saldo, quick action chips, dan daftar transaksi terbaru.
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
    final inkColor = CityWalletUi.ink(context);

    return Scaffold(
      backgroundColor: CityWalletUi.scaffoldBg(context),
      appBar: AppBar(
        backgroundColor: CityWalletUi.cardBg(context),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        leading: canPop
            ? IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.arrow_back, color: inkColor, size: 22),
                tooltip: 'Kembali',
              )
            : null,
        title: Text(
          'Dompet Saya',
          style: CityWalletUi.appBarTitleStyle(context),
        ),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                onPressed: () => showWalletNotifications(context),
                icon: Icon(
                  Icons.notifications_none_rounded,
                  color: inkColor,
                  size: 21,
                ),
                tooltip: 'Notifikasi',
              ),
              if (_notificationCount > 0)
                Positioned(
                  right: 11,
                  top: 12,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: CityWalletUi.errorRed,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            onPressed: _isLoading ? null : _load,
            icon: Icon(Icons.refresh, color: inkColor, size: 20),
            tooltip: 'Muat ulang',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: CityWalletUi.lineColor(context)),
        ),
      ),
      body: _isLoading
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
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                        children: [
                          if (_v1Summary?.isFrozen == true) _buildFrozenBanner(),
                          _buildSaldoCard(),
                          const SizedBox(height: 16),
                          _buildQuickActions(),
                          const SizedBox(height: 24),
                          _buildRiwayatSection(),
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
      bottomNavigationBar: DriverBottomNavigation(
        currentIndex: 2,
        onTap: (index) {
          if (index == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const DriverHomeScreen()),
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
              if (_v1Summary != null) ...[
                EnvironmentModeBadge(
                  mode: _v1Summary!.mode,
                  isSimulated: _v1Summary!.isSandboxOrDemo,
                ),
                const SizedBox(width: 6),
              ],
              GestureDetector(
                onTap: () => setState(() => _hideBalance = !_hideBalance),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    _hideBalance
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 18,
                    color: Colors.white70,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _hideBalance ? '••••••' : formatRupiah(available),
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
                  value: _hideBalance ? '••••••' : formatRupiah(pending),
                ),
              ),
              Container(width: 1, height: 28, color: Colors.white24),
              const SizedBox(width: 12),
              Expanded(
                child: _statColumn(
                  label: 'Total saldo',
                  value: _hideBalance ? '••••••' : formatRupiah(total),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: canWithdraw ? _openTarikSaldo : null,
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
              icon: const Icon(Icons.outbond_outlined, size: 18),
              label: const Text('Tarik Saldo'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statColumn({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.caption.copyWith(
            fontSize: 11.5,
            color: Colors.white70,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTypography.titleSmall.copyWith(
            fontSize: 13.5,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  // ───────────────────────── QUICK ACTIONS ─────────────────────────

  Widget _buildQuickActions() {
    return Row(
      children: [
        _actionChip(Icons.history_rounded, 'Riwayat', _openHistory),
        const SizedBox(width: 10),
        _actionChip(
          Icons.notifications_none_rounded,
          'Notifikasi',
          () => showWalletNotifications(context),
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

  // ───────────────────────── RIWAYAT ─────────────────────────

  Widget _buildRiwayatSection() {
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
              onPressed: _openHistory,
              style: CityWalletUi.textButtonStyle,
              child: const Text('Lihat Semua'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_recent.isEmpty)
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
                  'Belum ada transaksi dompet',
                  style: CityWalletUi.cardTitleStyle(context).copyWith(
                    fontSize: 13.5,
                    color: CityWalletUi.secondaryInk(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pendapatan pengantaran dan penarikan saldo Anda akan tercatat di sini.',
                  textAlign: TextAlign.center,
                  style: CityWalletUi.captionStyle(context),
                ),
              ],
            ),
          )
        else
          ..._recent.map(
            (item) => WalletHistoryTile(
              item: item,
              cardStyle: true,
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
          ),
      ],
    );
  }
}
