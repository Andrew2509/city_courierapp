import 'dart:async';

import 'package:city_courierapp/core/config/app_colors.dart';
import 'package:city_courierapp/core/utils/currency_format.dart';
import 'package:city_courierapp/models/wallet/wallet_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Komponen & token UI standar Wallet City Courier (putih bersih, aksen
/// `#FA880F`, border `#E8E8E8`, radius `10–14`, tipografi `#191B23` / `#64748B`).
class CityWalletUi {
  CityWalletUi._();

  static const Color inkPrimary = Color(0xFF191B23);
  static const Color inkSecondary = Color(0xFF64748B);
  static const Color inkMuted = Color(0xFF94A3B8);
  static const Color borderColor = Color(0xFFE8E8E8);
  static const Color dividerColor = Color(0xFFF1F5F9);
  static const Color disabledBg = Color(0xFFF1F5F9);
  static const Color errorRed = Color(0xFFDC2626);

  /// Header atas seragam bergaya aplikasi bawaan (tombol kembali + judul di tengah).
  static Widget buildHeader(
    BuildContext context, {
    required String title,
    Widget? trailing,
  }) {
    return Container(
      color: AppColors.backgroundColor,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: inkPrimary),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: inkPrimary,
              ),
            ),
          ),
          trailing ?? const SizedBox(width: 48),
        ],
      ),
    );
  }

  /// Label field di atas input agar rapi dan konsisten.
  static Widget fieldLabel(String label, {Widget? trailing}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: inkPrimary,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }

  /// Dekorasi input field standar (`borderRadius: 10`, `#E8E8E8` -> `#FA880F`).
  static InputDecoration inputDecoration({
    required String hintText,
    String? prefixText,
    TextStyle? prefixStyle,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Color(0xFFCBD5E1),
      ),
      prefixText: prefixText,
      prefixStyle: prefixStyle,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: borderColor),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: dividerColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primaryOrange, width: 1.5),
      ),
    );
  }

  /// Style tombol utama (`#FA880F`, `radius: 10`, `elevation: 0`, tinggi `46`).
  static ButtonStyle primaryButtonStyle({bool enabled = true}) {
    return ElevatedButton.styleFrom(
      backgroundColor: enabled ? AppColors.primaryOrange : disabledBg,
      foregroundColor: enabled ? Colors.white : inkMuted,
      disabledBackgroundColor: disabledBg,
      disabledForegroundColor: inkMuted,
      elevation: 0,
      minimumSize: const Size.fromHeight(46),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  /// Style tombol sekunder/outline seragam (`#FFFFFF`, border `#E8E8E8`, `radius: 10`, tinggi `46`).
  static ButtonStyle secondaryButtonStyle({Color? borderTint, Color? fgColor}) {
    return OutlinedButton.styleFrom(
      backgroundColor: Colors.white,
      foregroundColor: fgColor ?? inkPrimary,
      elevation: 0,
      minimumSize: const Size.fromHeight(46),
      side: BorderSide(color: borderTint ?? borderColor),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  /// Bottom bar sticky bergaya native (`TarikDanaScreen`), lengkap dengan safe area
  /// dan catatan keamanan opsional di bawah tombol.
  static Widget stickyBottomBar(
    BuildContext context, {
    required Widget child,
    String? securityNote,
    IconData securityIcon = Icons.lock_outline,
  }) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: dividerColor)),
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
                  child: Icon(securityIcon, size: 12, color: inkMuted),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    securityNote,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: inkMuted,
                      height: 1.3,
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
      child: const Text(
        'LIVE PRODUCTION',
        style: TextStyle(
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

    if (['settled', 'paid', 'completed', 'active', 'available', 'verified']
        .contains(s)) {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF166534);
    } else if (['pending', 'processing', 'requested', 'reserved'].contains(s)) {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFF92400E);
    } else if (['failed', 'expired', 'rejected', 'frozen', 'reversed']
        .contains(s)) {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFF991B1B);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(
        s.toUpperCase(),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: CityWalletUi.borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isCredit
                    ? const Color(0xFFECFDF5)
                    : AppColors.primaryOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isCredit ? Icons.south_west_rounded : Icons.north_east_rounded,
                color: isCredit ? const Color(0xFF15803D) : AppColors.primaryOrange,
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
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: CityWalletUi.inkPrimary,
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
                            style: const TextStyle(
                              fontSize: 11,
                              color: CityWalletUi.inkMuted,
                            ),
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
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color:
                    isCredit ? const Color(0xFF15803D) : CityWalletUi.inkPrimary,
              ),
            ),
          ],
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
              size: 44,
              color: Color(0xFFDC2626),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: CityWalletUi.inkSecondary,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text(
                'Coba Lagi',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
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
      if (checking || result != null || errorMessage != null || _lastQueryKey.isNotEmpty) {
        checking = false;
        result = null;
        errorMessage = null;
        _lastQueryKey = '';
        notifyListeners();
      }
      return;
    }

    final queryKey = '$destinationType|$channelCode|$digits';
    if (queryKey == _lastQueryKey && !checking && (result != null || errorMessage != null)) {
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: AppColors.primaryOrange.withValues(alpha: 0.25),
          ),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primaryOrange,
              ),
            ),
            SizedBox(width: 9),
            Expanded(
              child: Text(
                'Mengecek nama pemilik akun secara real-time...',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: CityWalletUi.inkPrimary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final res = controller.result;
    if (res != null && res.found && res.accountHolderName != null) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: const Color(0xFFBBF7D0)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.verified_rounded,
              size: 16,
              color: Color(0xFF15803D),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Terdeteksi: ${res.accountHolderName!}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF166534),
                ),
              ),
            ),
            if (controller.manualOverride && onUseDetectedName != null)
              GestureDetector(
                onTap: onUseDetectedName,
                child: const Text(
                  'Gunakan',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryOrange,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    if (res != null && res.supported && !res.found) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 16,
              color: CityWalletUi.errorRed,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                res.message ?? 'Nomor rekening/e-wallet tidak ditemukan.',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF991B1B),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (res != null && !res.supported) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: CityWalletUi.borderColor),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.info_outline_rounded,
              size: 16,
              color: CityWalletUi.inkSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                res.message ??
                    'Cek nama otomatis belum tersedia pada kanal ini. Isi nama sesuai akun.',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: CityWalletUi.inkSecondary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (controller.errorMessage != null) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: CityWalletUi.borderColor),
        ),
        child: Text(
          controller.errorMessage!,
          style: const TextStyle(
            fontSize: 11.5,
            color: CityWalletUi.inkSecondary,
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
