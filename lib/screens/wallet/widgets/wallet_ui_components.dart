import 'dart:async';

import 'package:city_courierapp/core/config/app_typography.dart';
import 'package:city_courierapp/core/utils/currency_format.dart';
import 'package:city_courierapp/models/wallet/wallet_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Komponen & token UI standar Wallet City Courier yang selaras dengan desain
/// bawaan aplikasi (`#EC5B13`, latar `#F9FAFB` / `#0F172A`, kartu putih/slate
/// radius `16`, tipografi `AppTypography` sistem, serta tombol `radius: 14`).
class CityWalletUi {
  CityWalletUi._();

  static const Color primaryColor = Color(0xFFEC5B13);
  static const Color primaryDark = Color(0xFFEA580C);

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryColor, primaryDark],
  );

  static const Color inkPrimary = Color(0xFF0F172A);
  static const Color inkSecondary = Color(0xFF64748B);
  static const Color inkMuted = Color(0xFF94A3B8);
  static const Color borderColor = Color(0xFFE2E8F0);
  static const Color dividerColor = Color(0xFFF1F5F9);
  static const Color disabledBg = Color(0xFFE2E8F0);
  static const Color errorRed = Color(0xFFDC2626);
  static const Color successGreen = Color(0xFF16A34A);

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color scaffoldBg(BuildContext context) =>
      isDark(context) ? const Color(0xFF0F172A) : const Color(0xFFF9FAFB);

  static Color cardBg(BuildContext context) =>
      isDark(context) ? const Color(0xFF1E293B) : Colors.white;

  static Color subtleBg(BuildContext context) =>
      isDark(context) ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

  static Color ink(BuildContext context) =>
      isDark(context) ? Colors.white : inkPrimary;

  static Color secondaryInk(BuildContext context) =>
      isDark(context) ? Colors.grey.shade400 : inkSecondary;

  static Color mutedInk(BuildContext context) =>
      isDark(context) ? Colors.grey.shade500 : inkMuted;

  static Color lineColor(BuildContext context) => isDark(context)
      ? Colors.white.withValues(alpha: 0.08)
      : borderColor;

  static Color divider(BuildContext context) => isDark(context)
      ? Colors.white.withValues(alpha: 0.06)
      : dividerColor;

  static Color disabledSurface(BuildContext context) =>
      isDark(context) ? const Color(0xFF334155) : disabledBg;

  static TextStyle appBarTitleStyle(BuildContext context) =>
      AppTypography.titleMedium.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.bold,
        color: ink(context),
      );

  static TextStyle sectionTitleStyle(BuildContext context) =>
      AppTypography.titleSmall.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: ink(context),
      );

  static TextStyle cardTitleStyle(BuildContext context) =>
      AppTypography.titleSmall.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: ink(context),
      );

  static TextStyle bodyStyle(BuildContext context) =>
      AppTypography.bodySmall.copyWith(
        fontSize: 13,
        color: secondaryInk(context),
      );

  static TextStyle captionStyle(BuildContext context) =>
      AppTypography.caption.copyWith(
        fontSize: 12,
        color: mutedInk(context),
      );

  static String formatShortDateTime(
    DateTime value, {
    bool includeWib = false,
  }) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    final base = '$day ${months[value.month - 1]} ${value.year}, $hour:$minute';
    return includeWib ? '$base WIB' : base;
  }

  static TextStyle get buttonTextStyle => AppTypography.titleSmall.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.bold,
      );

  static BoxDecoration heroCardDecoration() => BoxDecoration(
        gradient: primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      );

  static BoxDecoration cardDecoration(
    BuildContext context, {
    bool isHighlighted = false,
    double radius = 16,
  }) {
    final dark = isDark(context);
    return BoxDecoration(
      color: cardBg(context),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: isHighlighted ? primaryColor : lineColor(context),
        width: isHighlighted ? 1.5 : 1,
      ),
      boxShadow: dark
          ? null
          : [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
    );
  }

  static BoxDecoration noticeDecoration(BuildContext context) {
    final dark = isDark(context);
    return BoxDecoration(
      color: dark ? const Color(0xFF2A2113) : const Color(0xFFFFF7ED),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: dark ? const Color(0xFF4A3A12) : const Color(0xFFFED7AA),
      ),
    );
  }

  static void showSnackBar(
    BuildContext context,
    String message, {
    Color? backgroundColor,
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: AppTypography.bodySmall.copyWith(
              color: Colors.white,
              fontSize: 13,
            ),
          ),
          backgroundColor: backgroundColor ?? const Color(0xFF1E293B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  /// Menampilkan status hasil penarikan real-time (`completed`, `processing`, atau `failed`).
  static void showWithdrawalOutcomeSnackBar(
    BuildContext context,
    PayoutTransactionV1 payout,
  ) {
    final st = payout.status.toLowerCase();
    if (st == 'failed' || st == 'reversed') {
      final reason = (payout.failureReason ?? '').trim();
      showSnackBar(
        context,
        reason.isNotEmpty
            ? 'Penarikan gagal diproses: $reason'
            : 'Penarikan gagal diproses. Saldo tertahan telah dikembalikan.',
        backgroundColor: errorRed,
      );
      return;
    }

    final message = switch (st) {
      'completed' => 'Penarikan dana berhasil diselesaikan.',
      'processing' => 'Penarikan dana sedang diproses penyedia pembayaran.',
      _ => 'Permintaan penarikan dana berhasil dikirim.',
    };
    showSnackBar(context, message, backgroundColor: successGreen);
  }

  /// AppBar standar bawaan aplikasi untuk semua halaman City Wallet.
  static PreferredSizeWidget buildAppBar(
    BuildContext context, {
    required String title,
    List<Widget>? actions,
    VoidCallback? onBack,
  }) {
    final inkColor = ink(context);
    return AppBar(
      backgroundColor: cardBg(context),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      leading: IconButton(
        onPressed: onBack ?? () => Navigator.pop(context),
        icon: Icon(Icons.arrow_back, color: inkColor, size: 22),
        tooltip: 'Kembali',
      ),
      title: Text(
        title,
        style: appBarTitleStyle(context),
      ),
      actions: actions,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: lineColor(context)),
      ),
    );
  }

  /// Header atas seragam bergaya aplikasi bawaan (tombol kembali + judul di tengah).
  static Widget buildHeader(
    BuildContext context, {
    required String title,
    Widget? trailing,
  }) {
    final inkColor = ink(context);
    return Container(
      decoration: BoxDecoration(
        color: cardBg(context),
        border: Border(bottom: BorderSide(color: lineColor(context))),
      ),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back, color: inkColor, size: 22),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: appBarTitleStyle(context),
            ),
          ),
          trailing ?? const SizedBox(width: 48),
        ],
      ),
    );
  }

  /// Label field di atas input agar rapi dan konsisten.
  static Widget fieldLabel(
    String label, {
    Widget? trailing,
    BuildContext? context,
  }) {
    final labelColor = context != null ? ink(context) : inkPrimary;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTypography.titleSmall.copyWith(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: labelColor,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }

  /// Dekorasi input field standar bawaan aplikasi (`borderRadius: 14`).
  static InputDecoration inputDecoration({
    required String hintText,
    String? prefixText,
    TextStyle? prefixStyle,
    Widget? prefixIcon,
    Widget? suffixIcon,
    BuildContext? context,
  }) {
    final dark = context != null && isDark(context);
    final fill = context != null ? cardBg(context) : Colors.white;
    final line = context != null ? lineColor(context) : borderColor;
    final div = context != null ? divider(context) : dividerColor;
    final hintColor = dark ? Colors.grey.shade500 : inkMuted;

    return InputDecoration(
      hintText: hintText,
      hintStyle: AppTypography.bodySmall.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: hintColor,
      ),
      prefixText: prefixText,
      prefixStyle: prefixStyle,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: fill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: line),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: div),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: primaryColor, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: errorRed),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: errorRed, width: 1.5),
      ),
    );
  }

  /// Style tombol utama bawaan aplikasi (`#EC5B13`, `radius: 14`, tinggi `48`).
  static ButtonStyle primaryButtonStyle({
    bool enabled = true,
    BuildContext? context,
  }) {
    final disabledFill =
        context != null ? disabledSurface(context) : disabledBg;
    final disabledFg = context != null ? mutedInk(context) : inkMuted;
    return ElevatedButton.styleFrom(
      backgroundColor: enabled ? primaryColor : disabledFill,
      foregroundColor: enabled ? Colors.white : disabledFg,
      disabledBackgroundColor: disabledFill,
      disabledForegroundColor: disabledFg,
      elevation: 0,
      minimumSize: const Size.fromHeight(48),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      textStyle: buttonTextStyle,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }

  /// Style tombol sekunder/outline bawaan aplikasi (`radius: 14`, tinggi `48`).
  static ButtonStyle secondaryButtonStyle({
    Color? borderTint,
    Color? fgColor,
    BuildContext? context,
  }) {
    final bg = context != null ? cardBg(context) : Colors.white;
    final fg = fgColor ?? (context != null ? ink(context) : inkPrimary);
    final border =
        borderTint ?? (context != null ? lineColor(context) : borderColor);
    return OutlinedButton.styleFrom(
      backgroundColor: bg,
      foregroundColor: fg,
      elevation: 0,
      minimumSize: const Size.fromHeight(48),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      textStyle: AppTypography.titleSmall.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide(color: border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }

  static ButtonStyle get textButtonStyle => TextButton.styleFrom(
        foregroundColor: primaryColor,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: AppTypography.titleSmall.copyWith(
          fontSize: 12.5,
          fontWeight: FontWeight.bold,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      );

  /// Bottom bar sticky bergaya bawaan aplikasi, lengkap dengan safe area
  /// dan catatan keamanan opsional di bawah tombol.
  static Widget stickyBottomBar(
    BuildContext context, {
    required Widget child,
    String? securityNote,
    IconData securityIcon = Icons.lock_outline,
  }) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        (bottomPad > 0 ? bottomPad : 12) + 4,
      ),
      decoration: BoxDecoration(
        color: cardBg(context),
        border: Border(top: BorderSide(color: lineColor(context))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          child,
          if (securityNote != null) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1.5),
                  child: Icon(securityIcon, size: 13, color: mutedInk(context)),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    securityNote,
                    textAlign: TextAlign.center,
                    style: captionStyle(context).copyWith(
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Formatter ribuan otomatis ("50000" -> "50.000") untuk input nominal Rupiah.
class RupiahDigitsInputFormatter extends TextInputFormatter {
  const RupiahDigitsInputFormatter();

  static String formatDigits(int amount) {
    final raw = amount.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < raw.length; i++) {
      buffer.write(raw[i]);
      final remaining = raw.length - i - 1;
      if (remaining > 0 && remaining % 3 == 0) {
        buffer.write('.');
      }
    }
    return buffer.toString();
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(text: '');
    }
    final parsed = int.tryParse(digits);
    final formatted = parsed != null ? formatDigits(parsed) : digits;
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class EnvironmentModeBadge extends StatelessWidget {
  final String mode;
  final bool isSimulated;

  const EnvironmentModeBadge({
    super.key,
    required this.mode,
    this.isSimulated = false,
  });

  @override
  Widget build(BuildContext context) {
    final lower = mode.toLowerCase();
    if (lower != 'production') {
      return const SizedBox.shrink();
    }

    const bg = Color(0xFFDCFCE7);
    const fg = Color(0xFF166534);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
      child: Text(
        'LIVE PRODUCTION',
        style: AppTypography.caption.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: fg,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class WalletStatusChip extends StatelessWidget {
  final String status;

  const WalletStatusChip({super.key, required this.status});

  static String labelFor(String status) {
    switch (status.trim().toLowerCase()) {
      case 'settled':
      case 'paid':
      case 'completed':
      case 'success':
      case 'active':
      case 'available':
        return 'Berhasil';
      case 'processing':
      case 'approved':
        return 'Diproses';
      case 'pending':
      case 'requested':
      case 'reserved':
        return 'Menunggu';
      case 'failed':
      case 'expired':
      case 'rejected':
      case 'frozen':
        return 'Gagal';
      case 'cancelled':
      case 'reversed':
        return 'Dibatalkan';
      default:
        return status.isEmpty ? 'Menunggu' : status;
    }
  }

  static Color colorFor(String status) {
    switch (status.trim().toLowerCase()) {
      case 'settled':
      case 'paid':
      case 'completed':
      case 'success':
      case 'active':
      case 'available':
        return CityWalletUi.successGreen;
      case 'processing':
      case 'approved':
      case 'pending':
      case 'requested':
      case 'reserved':
        return const Color(0xFFD97706);
      case 'failed':
      case 'expired':
      case 'rejected':
      case 'frozen':
        return CityWalletUi.errorRed;
      default:
        return CityWalletUi.inkSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase();
    Color bg = const Color(0xFFE2E8F0);
    Color fg = const Color(0xFF334155);

    if ([
      'settled',
      'paid',
      'completed',
      'active',
      'available',
      'verified',
      'auto_verified',
    ].contains(s)) {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF166534);
    } else if ([
      'pending',
      'processing',
      'requested',
      'reserved',
      'unverified',
      'manual',
    ].contains(s)) {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFF92400E);
    } else if ([
      'failed',
      'expired',
      'rejected',
      'frozen',
      'reversed',
      'verification_failed',
    ].contains(s)) {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFF991B1B);
    }

    final displayLabel = switch (s) {
      'auto_verified' => 'TERVERIFIKASI',
      'unverified' => 'BELUM TERVERIFIKASI',
      'unavailable' => 'TIDAK TERSEDIA',
      'verification_failed' => 'GAGAL DIVERIFIKASI',
      _ => s.toUpperCase(),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(
        displayLabel,
        style: AppTypography.caption.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

class WalletTxTile extends StatelessWidget {
  final WalletTransactionV1 tx;
  final VoidCallback? onTap;
  final bool compactDashboardStyle;

  const WalletTxTile({
    super.key,
    required this.tx,
    this.onTap,
    this.compactDashboardStyle = false,
  });

  @override
  Widget build(BuildContext context) {
    final isCredit = tx.isCredit;
    final dark = CityWalletUi.isDark(context);
    final normalized = tx.status.toLowerCase();
    final isSuccess = const {'completed', 'settled', 'paid', 'success'}
        .contains(normalized);

    final content = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(compactDashboardStyle ? 12 : 14),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compactDashboardStyle ? 2 : 14,
            vertical: compactDashboardStyle ? 10 : 12,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isCredit
                      ? (dark
                          ? const Color(0xFF064E3B)
                          : const Color(0xFFECFDF5))
                      : CityWalletUi.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isCredit
                      ? (compactDashboardStyle
                          ? Icons.save_alt_rounded
                          : Icons.south_west_rounded)
                      : Icons.north_east_rounded,
                  color: isCredit
                      ? CityWalletUi.successGreen
                      : CityWalletUi.primaryColor,
                  size: compactDashboardStyle ? 20 : 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.description.isNotEmpty
                          ? tx.description
                          : tx.type.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CityWalletUi.cardTitleStyle(context).copyWith(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: compactDashboardStyle ? 3 : 4),
                    if (compactDashboardStyle)
                      Row(
                        children: [
                          if (tx.createdAt != null ||
                              (tx.referenceId ?? '').isNotEmpty)
                            Flexible(
                              child: Text(
                                tx.createdAt != null
                                    ? CityWalletUi.formatShortDateTime(
                                        tx.createdAt!.toLocal(),
                                      )
                                    : tx.referenceId!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: CityWalletUi.captionStyle(context)
                                    .copyWith(fontSize: 11.5),
                              ),
                            ),
                          if (!isSuccess)
                            Text(
                              (tx.createdAt != null ||
                                      (tx.referenceId ?? '').isNotEmpty)
                                  ? ' • ${WalletStatusChip.labelFor(tx.status)}'
                                  : WalletStatusChip.labelFor(tx.status),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.caption.copyWith(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: WalletStatusChip.colorFor(tx.status),
                              ),
                            ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          WalletStatusChip(status: tx.status),
                          const SizedBox(width: 6),
                          if (tx.referenceId != null)
                            Expanded(
                              child: Text(
                                tx.referenceId!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: CityWalletUi.captionStyle(context)
                                    .copyWith(fontSize: 11),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${isCredit ? '+' : '-'}${formatRupiah(tx.amount)}',
                style: AppTypography.titleSmall.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                  color: isCredit
                      ? CityWalletUi.successGreen
                      : CityWalletUi.ink(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (compactDashboardStyle) {
      return content;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: CityWalletUi.cardDecoration(context, radius: 14),
      child: content,
    );
  }
}

class WalletErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const WalletErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: CityWalletUi.errorRed,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: CityWalletUi.bodyStyle(context),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              style: CityWalletUi.primaryButtonStyle(context: context).copyWith(
                minimumSize: const WidgetStatePropertyAll(Size(160, 46)),
              ),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Controller debounced (450ms) untuk memeriksa nama pemilik rekening bank atau
/// akun e-wallet secara real-time saat pengguna mengetik nomor tujuan.
class DestinationNameInquiryController extends ChangeNotifier {
  final Future<DestinationInquiryResult> Function({
    required String destinationType,
    required String channelCode,
    required String accountNumber,
  }) inquireFn;

  Timer? _debounce;
  int _seq = 0;
  bool _disposed = false;

  bool checking = false;
  bool manualOverride = false;
  DestinationInquiryResult? result;
  String? errorMessage;
  String _lastQueryKey = '';
  String? _lastAutoFilledName;

  DestinationNameInquiryController({required this.inquireFn});

  bool get hasAutoFilled =>
      !manualOverride &&
      result != null &&
      result!.found &&
      result!.accountHolderName != null;

  void onManualNameEdited(String currentText) {
    if (_lastAutoFilledName != null &&
        currentText.trim() != _lastAutoFilledName) {
      manualOverride = true;
      notifyListeners();
    }
  }

  void restoreAutoFill(TextEditingController holderController) {
    final name = result?.accountHolderName;
    if (name == null || name.isEmpty) return;
    manualOverride = false;
    _lastAutoFilledName = name;
    holderController.text = name;
    holderController.selection = TextSelection.collapsed(offset: name.length);
    notifyListeners();
  }

  void reset() {
    _debounce?.cancel();
    _seq++;
    checking = false;
    manualOverride = false;
    result = null;
    errorMessage = null;
    _lastQueryKey = '';
    _lastAutoFilledName = null;
    notifyListeners();
  }

  void schedule({
    required String destinationType,
    required String channelCode,
    required String rawNumber,
    required TextEditingController holderController,
  }) {
    final digits = rawNumber.replaceAll(RegExp(r'\D'), '');
    final minLen = destinationType == 'ewallet' ? 10 : 8;

    if (digits.length < minLen) {
      _debounce?.cancel();
      _seq++;
      final clearedOldAuto = !manualOverride &&
          _lastAutoFilledName != null &&
          holderController.text.trim() == _lastAutoFilledName;
      if (clearedOldAuto) {
        holderController.clear();
        _lastAutoFilledName = null;
      }
      if (checking ||
          result != null ||
          errorMessage != null ||
          _lastQueryKey.isNotEmpty) {
        checking = false;
        result = null;
        errorMessage = null;
        _lastQueryKey = '';
        notifyListeners();
      }
      return;
    }

    final queryKey = '$destinationType|$channelCode|$digits';
    if (queryKey == _lastQueryKey &&
        !checking &&
        (result != null || errorMessage != null)) {
      return;
    }

    _debounce?.cancel();
    checking = true;
    errorMessage = null;
    notifyListeners();

    final seq = ++_seq;
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      try {
        final res = await inquireFn(
          destinationType: destinationType,
          channelCode: channelCode,
          accountNumber: digits,
        );
        if (_disposed || seq != _seq) return;
        _lastQueryKey = queryKey;
        checking = false;
        result = res;
        errorMessage = null;

        if (res.found && res.accountHolderName != null) {
          final shouldFill = !manualOverride &&
              (holderController.text.trim().isEmpty ||
                  holderController.text.trim() == _lastAutoFilledName);
          if (shouldFill) {
            final name = res.accountHolderName!;
            _lastAutoFilledName = name;
            holderController.text = name;
            holderController.selection =
                TextSelection.collapsed(offset: name.length);
          }
        } else if (!manualOverride &&
            _lastAutoFilledName != null &&
            holderController.text.trim() == _lastAutoFilledName) {
          holderController.clear();
          _lastAutoFilledName = null;
        }
        notifyListeners();
      } catch (_) {
        if (_disposed || seq != _seq) return;
        checking = false;
        result = null;
        errorMessage =
            'Tidak dapat memeriksa nama otomatis. Silakan isi nama secara manual.';
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    super.dispose();
  }
}

/// Banner status real-time hasil cek nama pemilik rekening / e-wallet.
class DestinationInquiryStatusBanner extends StatelessWidget {
  final DestinationNameInquiryController controller;
  final VoidCallback? onUseDetectedName;

  const DestinationInquiryStatusBanner({
    super.key,
    required this.controller,
    this.onUseDetectedName,
  });

  @override
  Widget build(BuildContext context) {
    if (controller.checking) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: CityWalletUi.noticeDecoration(context),
        child: Row(
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: CityWalletUi.primaryColor,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                'Mengecek nama pemilik akun secara real-time...',
                style: AppTypography.caption.copyWith(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: CityWalletUi.ink(context),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final res = controller.result;
    if (res == null) {
      if (controller.errorMessage != null) {
        return _statusBox(
          context: context,
          bg: const Color(0xFFFEF2F2),
          border: const Color(0xFFFECACA),
          icon: Icons.wifi_off_rounded,
          iconColor: CityWalletUi.errorRed,
          title: 'Gagal diverifikasi',
          titleColor: const Color(0xFF991B1B),
          message: controller.errorMessage!,
          messageColor: const Color(0xFF7F1D1D),
        );
      }
      return const SizedBox.shrink();
    }

    // 1. Terverifikasi otomatis via Xendit Data Services Name Validator resmi.
    if (res.isAutoVerified && res.found && res.accountHolderName != null) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFBBF7D0)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.verified_rounded,
              size: 18,
              color: Color(0xFF15803D),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Terverifikasi otomatis',
                    style: AppTypography.caption.copyWith(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF15803D),
                    ),
                  ),
                  Text(
                    res.accountHolderName!,
                    style: AppTypography.caption.copyWith(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF166534),
                    ),
                  ),
                ],
              ),
            ),
            if (controller.manualOverride && onUseDetectedName != null)
              TextButton(
                onPressed: onUseDetectedName,
                style: CityWalletUi.textButtonStyle,
                child: const Text('Gunakan'),
              ),
          ],
        ),
      );
    }

    // 2. Gagal diverifikasi oleh API validator resmi.
    if (res.isVerificationFailed) {
      return _statusBox(
        context: context,
        bg: const Color(0xFFFEF2F2),
        border: const Color(0xFFFECACA),
        icon: Icons.error_outline_rounded,
        iconColor: CityWalletUi.errorRed,
        title: 'Gagal diverifikasi',
        titleColor: const Color(0xFF991B1B),
        message: res.message ??
            'Nomor rekening/e-wallet gagal diverifikasi. Periksa nomor atau isi nama secara manual.',
        messageColor: const Color(0xFF7F1D1D),
      );
    }

    // 3. Tidak tersedia (kanal payout belum didukung atau gateway Xendit dinonaktifkan).
    if (res.isUnavailable) {
      return _statusBox(
        context: context,
        bg: CityWalletUi.subtleBg(context),
        border: CityWalletUi.lineColor(context),
        icon: Icons.block_rounded,
        iconColor: CityWalletUi.mutedInk(context),
        title: 'Tidak tersedia',
        titleColor: CityWalletUi.ink(context),
        message: res.message ??
            'Kanal tujuan ini sedang tidak tersedia untuk payout Xendit.',
        messageColor: CityWalletUi.secondaryInk(context),
      );
    }

    // 4. Belum terverifikasi (Xendit Payouts standar tidak memiliki Account Name Inquiry universal).
    return _statusBox(
      context: context,
      bg: const Color(0xFFFFFBEB),
      border: const Color(0xFFFDE68A),
      icon: Icons.edit_note_rounded,
      iconColor: const Color(0xFFB45309),
      title: 'Belum terverifikasi',
      titleColor: const Color(0xFF92400E),
      message: res.message ??
          'Pengecekan nama otomatis tidak tersedia pada Xendit Payouts standar. Silakan isi nama pemilik rekening/e-wallet secara manual.',
      messageColor: const Color(0xFF78350F),
    );
  }

  Widget _statusBox({
    required BuildContext context,
    required Color bg,
    required Color border,
    required IconData icon,
    required Color iconColor,
    required String title,
    required Color titleColor,
    required String message,
    required Color messageColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 17, color: iconColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.caption.copyWith(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: AppTypography.caption.copyWith(
                    fontSize: 11.5,
                    height: 1.35,
                    color: messageColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Ilustrasi dompet 3D & koin emas untuk kartu saldo City Wallet.
class WalletHeroIllustration extends StatelessWidget {
  const WalletHeroIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 84,
      height: 68,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -2,
            left: 26,
            child: _coinCircle(size: 28),
          ),
          Positioned(
            top: 10,
            left: 6,
            child: Transform.rotate(
              angle: -0.06,
              child: Container(
                width: 68,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFFC59F),
                      Color(0xFFFF9F68),
                      Color(0xFFF97E41),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF9A3412).withValues(alpha: 0.28),
                      blurRadius: 10,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.only(left: 14),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'C',
                      style: AppTypography.titleLarge.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 24,
            right: 2,
            child: Transform.rotate(
              angle: -0.06,
              child: Container(
                width: 24,
                height: 16,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFE066), Color(0xFFF59F00)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.16),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(left: 5),
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFF3BF),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 6,
            child: _coinCircle(size: 22),
          ),
        ],
      ),
    );
  }

  Widget _coinCircle({required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFFFFE066), Color(0xFFF59F00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: const Color(0xFFFFF3BF),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9A3412).withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
    );
  }
}

/// Latar belakang header oranye gradasi dengan aksen lengkung lembut di pojok kanan atas,
/// dipakai bersama oleh halaman Dompet Kurir dan City Wallet Pelanggan.
class WalletOrangeBannerBackground extends StatelessWidget {
  final double height;

  const WalletOrangeBannerBackground({super.key, required this.height});

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Container(
        width: double.infinity,
        height: height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFEB5908),
              Color(0xFFFA5A00),
              Color(0xFFFF7A22),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -36,
              right: -28,
              child: Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            Positioned(
              top: 28,
              right: 20,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kartu saldo putih melayang yang tumpang-tindih di atas banner oranye.
class WalletFloatingBalanceCard extends StatelessWidget {
  final num availableBalance;
  final bool hideBalance;
  final VoidCallback onToggleHideBalance;
  final IconData leftStatIcon;
  final String leftStatLabel;
  final num leftStatAmount;
  final IconData rightStatIcon;
  final String rightStatLabel;
  final num rightStatAmount;
  final IconData primaryIcon;
  final String primaryLabel;
  final VoidCallback? onPrimaryPressed;

  const WalletFloatingBalanceCard({
    super.key,
    required this.availableBalance,
    required this.hideBalance,
    required this.onToggleHideBalance,
    required this.leftStatIcon,
    required this.leftStatLabel,
    required this.leftStatAmount,
    required this.rightStatIcon,
    required this.rightStatLabel,
    required this.rightStatAmount,
    required this.primaryIcon,
    required this.primaryLabel,
    this.onPrimaryPressed,
  });

  @override
  Widget build(BuildContext context) {
    final dark = CityWalletUi.isDark(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: CityWalletUi.cardBg(context),
        borderRadius: BorderRadius.circular(20),
        border: dark ? Border.all(color: CityWalletUi.lineColor(context)) : null,
        boxShadow: dark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Saldo Tersedia',
                  style: AppTypography.caption.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: CityWalletUi.secondaryInk(context),
                  ),
                ),
              ),
              GestureDetector(
                onTap: onToggleHideBalance,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    hideBalance
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                    color: CityWalletUi.ink(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            hideBalance ? 'Rp ••••••' : formatRupiah(availableBalance),
            style: AppTypography.headline1.copyWith(
              color: CityWalletUi.ink(context),
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: dark ? const Color(0xFF0F172A) : const Color(0xFFF6F7FA),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _statColumn(
                    context,
                    icon: leftStatIcon,
                    label: leftStatLabel,
                    value: hideBalance ? 'Rp ••••••' : formatRupiah(leftStatAmount),
                  ),
                ),
                Container(
                  width: 1,
                  height: 30,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  color: CityWalletUi.lineColor(context),
                ),
                Expanded(
                  child: _statColumn(
                    context,
                    icon: rightStatIcon,
                    label: rightStatLabel,
                    value:
                        hideBalance ? 'Rp ••••••' : formatRupiah(rightStatAmount),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: onPrimaryPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: CityWalletUi.primaryColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: CityWalletUi.disabledSurface(context),
                disabledForegroundColor: CityWalletUi.mutedInk(context),
                elevation: 0,
                textStyle: AppTypography.titleSmall.copyWith(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: Icon(primaryIcon, size: 19),
              label: Text(primaryLabel),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statColumn(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: CityWalletUi.primaryColor),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                  fontSize: 11.5,
                  color: CityWalletUi.secondaryInk(context),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.titleSmall.copyWith(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: CityWalletUi.ink(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Card tunggal putih untuk daftar ringkas Riwayat Transaksi di dashboard wallet.
class WalletDashboardHistoryCard extends StatelessWidget {
  final VoidCallback onSeeAll;
  final bool isEmpty;
  final String emptyTitle;
  final String emptySubtitle;
  final List<Widget> children;

  const WalletDashboardHistoryCard({
    super.key,
    required this.onSeeAll,
    required this.isEmpty,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final dark = CityWalletUi.isDark(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: CityWalletUi.cardBg(context),
        borderRadius: BorderRadius.circular(18),
        border: dark ? Border.all(color: CityWalletUi.lineColor(context)) : null,
        boxShadow: dark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Riwayat Transaksi',
                  style: AppTypography.titleSmall.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: CityWalletUi.ink(context),
                  ),
                ),
              ),
              InkWell(
                onTap: onSeeAll,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Lihat Semua',
                        style: AppTypography.caption.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: CityWalletUi.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 17,
                        color: CityWalletUi.primaryColor,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 36,
                      color: CityWalletUi.mutedInk(context),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      emptyTitle,
                      style: CityWalletUi.cardTitleStyle(context).copyWith(
                        fontSize: 13.5,
                        color: CityWalletUi.secondaryInk(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      emptySubtitle,
                      textAlign: TextAlign.center,
                      style: CityWalletUi.captionStyle(context),
                    ),
                  ],
                ),
              ),
            )
          else
            ...children,
        ],
      ),
    );
  }
}

/// Struk kertas bergerigi Bukti Transaksi untuk detail transaksi Kurir & Pelanggan.
class WalletReceiptPaper extends StatelessWidget {
  final String subtitle;
  final Color statusColor;
  final IconData statusIcon;
  final String statusHeading;
  final String? timestampText;
  final String amountLabel;
  final String amountText;
  final List<MapEntry<String, String>> rows;
  final String infoMessage;

  const WalletReceiptPaper({
    super.key,
    required this.subtitle,
    required this.statusColor,
    required this.statusIcon,
    required this.statusHeading,
    this.timestampText,
    required this.amountLabel,
    required this.amountText,
    required this.rows,
    required this.infoMessage,
  });

  @override
  Widget build(BuildContext context) {
    final dark = CityWalletUi.isDark(context);

    return PhysicalShape(
      clipper: const WalletReceiptClipper(),
      color: CityWalletUi.cardBg(context),
      elevation: dark ? 0 : 4,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 26, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  Container(
                    padding: dark
                        ? const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          )
                        : EdgeInsets.zero,
                    decoration: dark
                        ? BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.94),
                            borderRadius: BorderRadius.circular(10),
                          )
                        : null,
                    child: Image.asset(
                      'assets/images/Logo City Courie.png',
                      height: 48,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => Text(
                        'CityCourier',
                        style: AppTypography.titleLarge.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: CityWalletUi.primaryColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Bukti Transaksi',
                    style: AppTypography.titleMedium.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: CityWalletUi.ink(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.bodySmall.copyWith(
                      fontSize: 13,
                      color: CityWalletUi.secondaryInk(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            WalletDashedDivider(color: CityWalletUi.lineColor(context)),
            const SizedBox(height: 18),
            Center(
              child: Column(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(statusIcon, size: 28, color: Colors.white),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    statusHeading,
                    style: AppTypography.titleMedium.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                    ),
                  ),
                  if (timestampText != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      timestampText!,
                      style: AppTypography.caption.copyWith(
                        fontSize: 12.5,
                        color: CityWalletUi.secondaryInk(context),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            WalletDashedDivider(color: CityWalletUi.lineColor(context)),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: dark
                    ? CityWalletUi.primaryColor.withValues(alpha: 0.14)
                    : const Color(0xFFFFF4EC),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Text(
                    amountLabel,
                    textAlign: TextAlign.center,
                    style: AppTypography.titleSmall.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: CityWalletUi.ink(context),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    amountText,
                    textAlign: TextAlign.center,
                    style: AppTypography.headline1.copyWith(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: CityWalletUi.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Rincian Transaksi',
              style: CityWalletUi.cardTitleStyle(context).copyWith(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < rows.length; i++) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 11),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 4,
                      child: Text(
                        rows[i].key,
                        style: AppTypography.bodySmall.copyWith(
                          fontSize: 13,
                          color: CityWalletUi.secondaryInk(context),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 6,
                      child: Text(
                        rows[i].value,
                        textAlign: TextAlign.right,
                        style: AppTypography.bodySmall.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: CityWalletUi.ink(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (i < rows.length - 1)
                Divider(height: 1, color: CityWalletUi.divider(context)),
            ],
            const SizedBox(height: 8),
            WalletDashedDivider(color: CityWalletUi.lineColor(context)),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 20,
                  color: CityWalletUi.primaryColor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Informasi',
                        style: AppTypography.titleSmall.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: CityWalletUi.ink(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        infoMessage,
                        style: AppTypography.bodySmall.copyWith(
                          fontSize: 12.5,
                          height: 1.4,
                          color: CityWalletUi.secondaryInk(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Bar aksi bawah Bagikan & Selesai pada detail struk transaksi.
class WalletReceiptBottomActions extends StatelessWidget {
  final VoidCallback onShare;
  final VoidCallback onDone;

  const WalletReceiptBottomActions({
    super.key,
    required this.onShare,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CityWalletUi.cardBg(context),
        border: Border(
          top: BorderSide(color: CityWalletUi.lineColor(context), width: 0.8),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: onShare,
                    icon: const Icon(Icons.share_outlined, size: 19),
                    label: const Text('Bagikan'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: CityWalletUi.primaryColor,
                      backgroundColor: CityWalletUi.cardBg(context),
                      side: const BorderSide(
                        color: CityWalletUi.primaryColor,
                        width: 1.4,
                      ),
                      textStyle: CityWalletUi.buttonTextStyle.copyWith(
                        fontSize: 14.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: onDone,
                    icon: const Icon(Icons.check_circle, size: 19),
                    label: const Text('Selesai'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CityWalletUi.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      textStyle: CityWalletUi.buttonTextStyle.copyWith(
                        fontSize: 14.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WalletDashedDivider extends StatelessWidget {
  final Color color;

  const WalletDashedDivider({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _WalletDashedLinePainter(color: color),
      child: const SizedBox(width: double.infinity, height: 1),
    );
  }
}

class _WalletDashedLinePainter extends CustomPainter {
  final Color color;

  const _WalletDashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.1;
    const dashWidth = 5.0;
    const dashSpace = 4.0;
    double x = 0;
    while (x < size.width) {
      final endX = (x + dashWidth).clamp(0.0, size.width);
      canvas.drawLine(Offset(x, 0), Offset(endX, 0), paint);
      x += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(_WalletDashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}

class WalletReceiptClipper extends CustomClipper<Path> {
  const WalletReceiptClipper();

  @override
  Path getClip(Size size) {
    const toothWidth = 14.0;
    const toothHeight = 6.0;
    final path = Path()..moveTo(0, toothHeight);

    final count = (size.width / toothWidth).floor().clamp(1, 200);
    final step = size.width / count;

    for (var i = 0; i < count; i++) {
      final startX = i * step;
      path.quadraticBezierTo(
        startX + step / 2,
        0,
        startX + step,
        toothHeight,
      );
    }

    path.lineTo(size.width, size.height - toothHeight);

    for (var i = count - 1; i >= 0; i--) {
      final leftX = i * step;
      path.quadraticBezierTo(
        leftX + step / 2,
        size.height,
        leftX,
        size.height - toothHeight,
      );
    }

    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
