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

  const WalletTxTile({super.key, required this.tx, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isCredit = tx.isCredit;
    final dark = CityWalletUi.isDark(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: CityWalletUi.cardDecoration(context, radius: 14),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                        ? Icons.south_west_rounded
                        : Icons.north_east_rounded,
                    color: isCredit
                        ? const Color(0xFF15803D)
                        : CityWalletUi.primaryColor,
                    size: 18,
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
                      const SizedBox(height: 4),
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
                        ? const Color(0xFF15803D)
                        : CityWalletUi.ink(context),
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
