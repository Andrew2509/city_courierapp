import 'package:city_courierapp/core/config/app_typography.dart';
import 'package:city_courierapp/core/utils/auth_guard.dart';
import 'package:city_courierapp/core/utils/currency_format.dart';
import 'package:city_courierapp/models/wallet/wallet_models.dart';
import 'package:city_courierapp/screens/wallet/customer_refund_screen.dart';
import 'package:city_courierapp/screens/wallet/customer_wallet_dashboard_screen.dart';
import 'package:city_courierapp/screens/wallet/customer_withdrawal_screen.dart';
import 'package:city_courierapp/screens/wallet/topup_amount_screen.dart';
import 'package:city_courierapp/screens/wallet/wallet_transactions_screen.dart';
import 'package:city_courierapp/screens/wallet/widgets/wallet_ui_components.dart';
import 'package:city_courierapp/services/wallet/customer_wallet_service.dart';
import 'package:flutter/material.dart';

class ProfileWalletCard extends StatefulWidget {
  final Color primaryColor;
  final Color surfaceColor;
  final Color borderColor;
  final CustomerWalletSummary? wallet;
  final bool isLoading;
  final CustomerWalletService? walletService;
  final VoidCallback? onWalletUpdated;

  const ProfileWalletCard({
    super.key,
    required this.primaryColor,
    required this.surfaceColor,
    required this.borderColor,
    this.wallet,
    this.isLoading = false,
    this.walletService,
    this.onWalletUpdated,
  });

  @override
  State<ProfileWalletCard> createState() => _ProfileWalletCardState();
}

class _ProfileWalletCardState extends State<ProfileWalletCard> {
  bool _hideBalance = false;

  Future<void> _openDashboard() async {
    await AuthGuard.runWithAuth(
      context,
      onAuthenticated: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CustomerWalletDashboardScreen(
              service: widget.walletService,
            ),
          ),
        );
        widget.onWalletUpdated?.call();
      },
    );
  }

  Future<void> _openTopUp() async {
    await AuthGuard.runWithAuth(
      context,
      onAuthenticated: () async {
        final w = widget.wallet;
        if (w == null || w.isFrozen || !w.topupProviderEnabled) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CustomerWalletDashboardScreen(
                service: widget.walletService,
              ),
            ),
          );
          widget.onWalletUpdated?.call();
          return;
        }
        final changed = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => TopupAmountScreen(
              minAmount: w.topupMinIdr,
              maxAmount: w.topupMaxIdr,
              currentBalance: w.availableBalance,
              service: widget.walletService,
            ),
          ),
        );
        if (changed == true) {
          widget.onWalletUpdated?.call();
        }
      },
    );
  }

  Future<void> _openWithdrawal() async {
    await AuthGuard.runWithAuth(
      context,
      onAuthenticated: () async {
        final w = widget.wallet;
        if (w == null) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CustomerWalletDashboardScreen(
                service: widget.walletService,
              ),
            ),
          );
          widget.onWalletUpdated?.call();
          return;
        }
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CustomerWithdrawalScreen(
              wallet: w,
              service: widget.walletService,
            ),
          ),
        );
        widget.onWalletUpdated?.call();
      },
    );
  }

  Future<void> _openRefund() async {
    await AuthGuard.runWithAuth(
      context,
      onAuthenticated: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CustomerRefundScreen(
              service: widget.walletService,
            ),
          ),
        );
        widget.onWalletUpdated?.call();
      },
    );
  }

  Future<void> _openTransactions() async {
    await AuthGuard.runWithAuth(
      context,
      onAuthenticated: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WalletTransactionsScreen(
              service: widget.walletService,
            ),
          ),
        );
        widget.onWalletUpdated?.call();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final String balanceText = _hideBalance
        ? 'Rp ••••••'
        : formatRupiah(widget.wallet?.availableBalance ?? 0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Container(
        decoration: BoxDecoration(
          color: widget.surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.08)
                : widget.borderColor.withValues(alpha: 0.65),
          ),
          boxShadow: [
            BoxShadow(
              color: widget.primaryColor.withValues(
                alpha: isDarkMode ? 0.14 : 0.12,
              ),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: isDarkMode ? 0.25 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // Bagian atas oranye: Saldo & info City Wallet
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _openDashboard,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFFFF832B),
                        Color(0xFFEC5B13),
                        Color(0xFFE04808),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.account_balance_wallet_outlined,
                                  color: Colors.white,
                                  size: 22,
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'City Wallet',
                                      style: AppTypography.titleSmall.copyWith(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        height: 1.15,
                                      ),
                                    ),
                                    Text(
                                      widget.wallet?.isFrozen == true
                                          ? 'Wallet Dibekukan'
                                          : 'Saldo Anda',
                                      style: AppTypography.caption.copyWith(
                                        color: Colors.white.withValues(
                                          alpha: 0.9,
                                        ),
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w500,
                                        height: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: widget.isLoading &&
                                          widget.wallet == null
                                      ? Container(
                                          width: 120,
                                          height: 26,
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(
                                              alpha: 0.24,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                        )
                                      : FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            balanceText,
                                            style: AppTypography.headline1
                                                .copyWith(
                                              color: Colors.white,
                                              fontSize: 23,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: -0.4,
                                            ),
                                          ),
                                        ),
                                ),
                                const SizedBox(width: 10),
                                GestureDetector(
                                  onTap: () => setState(
                                    () => _hideBalance = !_hideBalance,
                                  ),
                                  behavior: HitTestBehavior.opaque,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.24,
                                      ),
                                      borderRadius: BorderRadius.circular(100),
                                    ),
                                    child: Icon(
                                      _hideBalance
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      const WalletHeroIllustration(),
                    ],
                  ),
                ),
              ),
            ),

            // Bagian bawah putih: 4 tombol cepat City Wallet
            Container(
              color: widget.surfaceColor,
              padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    _QuickActionItem(
                      label: 'Top Up',
                      onTap: _openTopUp,
                      isDarkMode: isDarkMode,
                      iconWidget: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: widget.primaryColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.add_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                    _verticalDivider(widget.borderColor, isDarkMode),
                    _QuickActionItem(
                      label: 'Tarik Dana',
                      onTap: _openWithdrawal,
                      isDarkMode: isDarkMode,
                      iconWidget: Icon(
                        Icons.outbond_rounded,
                        color: widget.primaryColor,
                        size: 25,
                      ),
                    ),
                    _verticalDivider(widget.borderColor, isDarkMode),
                    _QuickActionItem(
                      label: 'Refund',
                      onTap: _openRefund,
                      isDarkMode: isDarkMode,
                      iconWidget: Icon(
                        Icons.assignment_return_rounded,
                        color: widget.primaryColor,
                        size: 24,
                      ),
                    ),
                    _verticalDivider(widget.borderColor, isDarkMode),
                    _QuickActionItem(
                      label: 'Riwayat',
                      onTap: _openTransactions,
                      isDarkMode: isDarkMode,
                      iconWidget: Icon(
                        Icons.receipt_long_rounded,
                        color: widget.primaryColor,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _verticalDivider(Color borderColor, bool isDarkMode) {
    return VerticalDivider(
      width: 1,
      thickness: 1,
      indent: 6,
      endIndent: 6,
      color: isDarkMode
          ? Colors.white.withValues(alpha: 0.08)
          : borderColor.withValues(alpha: 0.7),
    );
  }
}

class _QuickActionItem extends StatelessWidget {
  final String label;
  final Widget iconWidget;
  final VoidCallback onTap;
  final bool isDarkMode;

  const _QuickActionItem({
    required this.label,
    required this.iconWidget,
    required this.onTap,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 28,
                  child: Center(child: iconWidget),
                ),
                const SizedBox(height: 5),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: AppTypography.caption.copyWith(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode
                          ? Colors.white.withValues(alpha: 0.9)
                          : const Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
