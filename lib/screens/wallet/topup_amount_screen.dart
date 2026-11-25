import 'package:city_courierapp/core/config/app_typography.dart';
import 'package:city_courierapp/core/utils/currency_format.dart';
import 'package:city_courierapp/models/wallet/wallet_models.dart';
import 'package:city_courierapp/screens/wallet/topup_instruction_screen.dart';
import 'package:city_courierapp/screens/wallet/widgets/wallet_ui_components.dart';
import 'package:city_courierapp/services/security/account_security_service.dart';
import 'package:city_courierapp/services/security/transaction_security_guard.dart';
import 'package:city_courierapp/services/wallet/customer_wallet_service.dart';
import 'package:city_courierapp/widgets/payment/payment_brand_logo.dart';
import 'package:flutter/material.dart';

class TopupAmountScreen extends StatefulWidget {
  final int minAmount;
  final int maxAmount;
  final int? currentBalance;
  final CustomerWalletService? service;
  final AccountSecurityService? securityService;

  const TopupAmountScreen({
    super.key,
    this.minAmount = 10000,
    this.maxAmount = 10000000,
    this.currentBalance,
    this.service,
    this.securityService,
  });

  @override
  State<TopupAmountScreen> createState() => _TopupAmountScreenState();
}

class _TopupAmountScreenState extends State<TopupAmountScreen> {
  static const List<int> _presets = [
    20000,
    50000,
    100000,
    250000,
    500000,
    1000000,
  ];

  late final CustomerWalletService _service =
      widget.service ?? CustomerWalletService.instance;
  late final AccountSecurityService _securityService =
      widget.securityService ?? AccountSecurityService.instance;
  final TextEditingController _controller = TextEditingController(
    text: RupiahDigitsInputFormatter.formatDigits(50000),
  );

  int? _walletBalance;
  CustomerWalletSummary? _walletSummary;
  TopupMethodsBundle? _bundle;
  TopupMethodOption? _selectedMethod;
  bool _loadingMethods = true;
  String? _methodsError;
  bool _submitting = false;
  int _selectedAmount = 50000;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _walletBalance = widget.currentBalance;
    _loadInitialData();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadMethods(),
      _loadWalletBalanceSilently(),
    ]);
  }

  Future<void> _loadWalletBalanceSilently() async {
    try {
      final wallet = await _service.getWallet();
      if (!mounted) return;
      setState(() {
        _walletSummary = wallet;
        _walletBalance ??= wallet.availableBalance;
      });
    } catch (_) {
      // Tetap tampil tanpa memblokir layar bila saldo gagal diambil.
    }
  }

  Future<void> _loadMethods() async {
    setState(() {
      _loadingMethods = true;
      _methodsError = null;
    });
    try {
      final bundle = await _service.getTopupMethods();
      if (!mounted) return;
      setState(() {
        _bundle = bundle;
        _selectedMethod = _pickDefaultMethod(bundle.methods);
        _loadingMethods = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _methodsError = e.toString();
        _loadingMethods = false;
      });
    }
  }

  TopupMethodOption? _pickDefaultMethod(List<TopupMethodOption> methods) {
    if (methods.isEmpty) return null;
    for (final m in methods) {
      if (m.paymentType == 'qris') return m;
    }
    return methods.first;
  }

  void _selectPreset(int amount) {
    setState(() {
      _selectedAmount = amount;
      _controller.text = RupiahDigitsInputFormatter.formatDigits(amount);
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
      _errorText = null;
    });
  }

  void _clearAmount() {
    setState(() {
      _selectedAmount = 0;
      _controller.clear();
      _errorText = null;
    });
  }

  void _onChanged(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    final parsed = int.tryParse(digits) ?? 0;
    setState(() {
      _selectedAmount = parsed;
      _errorText = null;
    });
  }

  Future<void> _openMethodPicker() async {
    final methods = _bundle?.methods ?? const [];
    if (methods.isEmpty) return;

    final picked = await showModalBottomSheet<TopupMethodOption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: CityWalletUi.cardBg(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Pilih Metode Pembayaran',
                  style: AppTypography.titleMedium.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: CityWalletUi.ink(sheetCtx),
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: methods.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, idx) {
                      final method = methods[idx];
                      final isSelected =
                          _selectedMethod?.channelCode == method.channelCode;
                      return Container(
                        decoration: CityWalletUi.cardDecoration(
                          sheetCtx,
                          isHighlighted: isSelected,
                          radius: 14,
                        ).copyWith(
                          color: isSelected
                              ? CityWalletUi.primaryColor.withValues(alpha: 0.06)
                              : CityWalletUi.cardBg(sheetCtx),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => Navigator.pop(sheetCtx, method),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  PaymentBrandLogo(
                                    method:
                                        '${method.channelCode} ${method.label}',
                                    size: 40,
                                    width: 54,
                                    borderRadius: 10,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          method.label,
                                          style: CityWalletUi.cardTitleStyle(
                                            sheetCtx,
                                          ).copyWith(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          method.feeIdr == 0
                                              ? 'Biaya admin gratis'
                                              : 'Biaya admin ${formatRupiah(method.feeIdr)}',
                                          style: CityWalletUi.captionStyle(
                                            sheetCtx,
                                          ).copyWith(
                                            fontSize: 12,
                                            color: CityWalletUi.secondaryInk(
                                              sheetCtx,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    isSelected
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_off,
                                    color: isSelected
                                        ? CityWalletUi.primaryColor
                                        : CityWalletUi.mutedInk(sheetCtx),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedMethod = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (_selectedAmount < widget.minAmount ||
        _selectedAmount > widget.maxAmount) {
      setState(() {
        _errorText =
            'Nominal harus antara ${formatRupiah(widget.minAmount)} dan ${formatRupiah(widget.maxAmount)}.';
      });
      return;
    }

    final option = _selectedMethod;
    if (option == null || _submitting) return;

    setState(() => _submitting = true);
    try {
      final auth = await TransactionSecurityGuard.authorize(
        context,
        biometricEnabled: _walletSummary?.biometricEnabled == true,
        hasTransactionPin: _walletSummary?.hasTransactionPin == true,
        biometricReason:
            'Verifikasi sidik jari atau wajah untuk melakukan top-up City Wallet',
        pinSubtitle: 'Masukkan 6 digit PIN transaksi untuk melanjutkan top-up.',
        verifyPinFn: _securityService.verifyPin,
        beforeDialog: () {
          if (mounted) setState(() => _submitting = false);
        },
      );
      if (!mounted) return;
      if (!auth.authorized) {
        if (auth.errorMessage != null) {
          CityWalletUi.showSnackBar(
            context,
            auth.errorMessage!,
            backgroundColor: CityWalletUi.errorRed,
          );
        }
        return;
      }
      if (!_submitting) setState(() => _submitting = true);

      final topup = await _service.createTopup(
        amount: _selectedAmount,
        paymentType: option.paymentType,
        channelCode: option.channelCode,
      );
      if (!mounted) return;
      final settled = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => TopupInstructionScreen(
            initialTopup: topup,
            service: _service,
          ),
        ),
      );
      if (settled == true && mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;
      CityWalletUi.showSnackBar(
        context,
        e.toString(),
        backgroundColor: CityWalletUi.errorRed,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool unavailable = _bundle != null &&
        (!_bundle!.providerEnabled || _bundle!.methods.isEmpty);
    final bool canSubmit = !_loadingMethods &&
        _methodsError == null &&
        !unavailable &&
        _selectedMethod != null &&
        !_submitting;
    final int adminFee = _selectedMethod?.feeIdr ?? 0;
    final int totalPay = _selectedAmount + adminFee;

    return Scaffold(
      backgroundColor: CityWalletUi.scaffoldBg(context),
      appBar: CityWalletUi.buildAppBar(context, title: 'Top-Up City Wallet'),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBalanceCard(),
                  const SizedBox(height: 12),
                  _buildNoticeBanner(),
                  const SizedBox(height: 18),
                  _buildAmountSection(),
                  const SizedBox(height: 20),
                  _buildPaymentMethodSection(unavailable),
                  const SizedBox(height: 20),
                  _buildConfirmationSection(adminFee, totalPay),
                ],
              ),
            ),
          ),
          CityWalletUi.stickyBottomBar(
            context,
            securityIcon: Icons.bolt_rounded,
            securityNote:
                'Saldo City Wallet bertambah otomatis setelah pembayaran dikonfirmasi.',
            child: ElevatedButton(
              onPressed: canSubmit ? _submit : null,
              style: CityWalletUi.primaryButtonStyle(
                enabled: canSubmit,
                context: context,
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Buat Instruksi Pembayaran'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepHeader(String step, String title) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            color: CityWalletUi.primaryColor,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            step,
            style: AppTypography.caption.copyWith(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              height: 1.0,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: AppTypography.titleSmall.copyWith(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: CityWalletUi.ink(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFF832B),
            Color(0xFFEC5B13),
            Color(0xFFE04808),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: CityWalletUi.primaryColor.withValues(alpha: 0.24),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(
            Icons.account_balance_wallet_outlined,
            color: Colors.white,
            size: 30,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Saldo City Wallet',
                        style: AppTypography.caption.copyWith(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.92),
                        ),
                      ),
                    ),
                    if (_bundle != null) ...[
                      const SizedBox(width: 6),
                      EnvironmentModeBadge(
                        mode: _bundle!.mode,
                        isSimulated: _bundle!.isSimulated,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    formatRupiah(_walletBalance ?? 0),
                    style: AppTypography.headline1.copyWith(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const WalletHeroIllustration(),
        ],
      ),
    );
  }

  Widget _buildNoticeBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: CityWalletUi.noticeDecoration(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 19,
            color: CityWalletUi.primaryColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Pilih nominal dan metode pembayaran untuk menambah saldo ke City Wallet.',
              style: AppTypography.bodySmall.copyWith(
                fontSize: 12,
                color: CityWalletUi.ink(context),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountSection() {
    final row1 = _presets.sublist(0, 3);
    final row2 = _presets.sublist(3, 6);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeader('1', 'Masukkan Nominal Top-Up'),
        const SizedBox(height: 10),
        TextField(
          controller: _controller,
          keyboardType: TextInputType.number,
          inputFormatters: const [RupiahDigitsInputFormatter()],
          onChanged: _onChanged,
          style: AppTypography.headline2.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: CityWalletUi.ink(context),
          ),
          decoration: CityWalletUi.inputDecoration(
            context: context,
            hintText: '0',
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 16, right: 6),
              child: Text(
                'Rp',
                style: AppTypography.headline2.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: CityWalletUi.mutedInk(context),
                ),
              ),
            ),
            suffixIcon: _controller.text.isNotEmpty
                ? IconButton(
                    onPressed: _clearAmount,
                    tooltip: 'Hapus nominal',
                    icon: Icon(
                      Icons.cancel_rounded,
                      size: 20,
                      color: CityWalletUi.mutedInk(context),
                    ),
                  )
                : null,
          ).copyWith(
            prefixIconConstraints: const BoxConstraints(
              minWidth: 0,
              minHeight: 0,
            ),
            errorText: _errorText,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Minimal ${formatRupiah(widget.minAmount)} • Maksimal ${formatRupiah(widget.maxAmount)}',
          style: CityWalletUi.captionStyle(context).copyWith(fontSize: 11.5),
        ),
        const SizedBox(height: 14),
        Text(
          'Pilih Nominal Cepat',
          style: AppTypography.titleSmall.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: CityWalletUi.ink(context),
          ),
        ),
        const SizedBox(height: 8),
        _presetRow(row1),
        const SizedBox(height: 8),
        _presetRow(row2),
      ],
    );
  }

  Widget _presetRow(List<int> amounts) {
    final dark = CityWalletUi.isDark(context);
    return Row(
      children: [
        for (int i = 0; i < amounts.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: ChoiceChip(
              label: SizedBox(
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    formatRupiah(amounts[i]),
                    textAlign: TextAlign.center,
                    style: AppTypography.titleSmall.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _selectedAmount == amounts[i]
                          ? CityWalletUi.primaryColor
                          : CityWalletUi.ink(context),
                    ),
                  ),
                ),
              ),
              labelPadding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 2,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              selected: _selectedAmount == amounts[i],
              showCheckmark: false,
              selectedColor: dark
                  ? CityWalletUi.primaryColor.withValues(alpha: 0.16)
                  : const Color(0xFFFFF5EE),
              backgroundColor: CityWalletUi.cardBg(context),
              side: BorderSide(
                color: _selectedAmount == amounts[i]
                    ? CityWalletUi.primaryColor
                    : CityWalletUi.lineColor(context),
                width: _selectedAmount == amounts[i] ? 1.5 : 1,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onSelected: (_) => _selectPreset(amounts[i]),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPaymentMethodSection(bool unavailable) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeader('2', 'Pilih Metode Pembayaran'),
        const SizedBox(height: 10),
        if (_loadingMethods)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: CityWalletUi.cardDecoration(context, radius: 14),
            child: Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: CityWalletUi.primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Memuat metode pembayaran...',
                    style:
                        CityWalletUi.bodyStyle(context).copyWith(fontSize: 13),
                  ),
                ),
              ],
            ),
          )
        else if (_methodsError != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: CityWalletUi.cardDecoration(context, radius: 14),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: CityWalletUi.errorRed,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _methodsError!,
                    style: CityWalletUi.bodyStyle(context).copyWith(
                      fontSize: 12,
                      color: CityWalletUi.errorRed,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _loadMethods,
                  style: CityWalletUi.textButtonStyle,
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          )
        else if (unavailable)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFF59E0B)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.pause_circle_outline_rounded,
                  color: Color(0xFFB45309),
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Metode Top-Up Tidak Tersedia',
                        style: AppTypography.titleSmall.copyWith(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF92400E),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _bundle!.disabledReason ??
                            'Gateway top-up (${_bundle!.activeProvider.toUpperCase()}) sedang dinonaktifkan oleh Admin.',
                        style: AppTypography.bodySmall.copyWith(
                          fontSize: 12,
                          color: const Color(0xFF78350F),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else if (_selectedMethod != null)
          Container(
            decoration: BoxDecoration(
              color: CityWalletUi.cardBg(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: CityWalletUi.primaryColor,
                width: 1.3,
              ),
              boxShadow: [
                BoxShadow(
                  color: CityWalletUi.primaryColor.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _openMethodPicker,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      PaymentBrandLogo(
                        method:
                            '${_selectedMethod!.channelCode} ${_selectedMethod!.label}',
                        size: 40,
                        width: 54,
                        borderRadius: 10,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedMethod!.label,
                              style: CityWalletUi.cardTitleStyle(context)
                                  .copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _selectedMethod!.feeIdr == 0
                                  ? 'Biaya admin gratis'
                                  : 'Biaya admin ${formatRupiah(_selectedMethod!.feeIdr)}',
                              style: CityWalletUi.captionStyle(context)
                                  .copyWith(
                                fontSize: 12,
                                color: CityWalletUi.secondaryInk(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: CityWalletUi.secondaryInk(context),
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildConfirmationSection(int adminFee, int totalPay) {
    final bool dark = CityWalletUi.isDark(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeader('3', 'Konfirmasi Top-Up'),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: CityWalletUi.cardDecoration(context, radius: 16),
          child: Column(
            children: [
              _summaryRow(
                'Metode Pembayaran',
                _selectedMethod?.label ?? '-',
              ),
              _summaryRow('Nominal Top-Up', formatRupiah(_selectedAmount)),
              _summaryRow(
                'Biaya Admin',
                adminFee == 0 ? 'Rp 0' : formatRupiah(adminFee),
                valueColor: adminFee == 0 ? CityWalletUi.successGreen : null,
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: dark
                      ? CityWalletUi.primaryColor.withValues(alpha: 0.16)
                      : const Color(0xFFFFF3E8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Total Pembayaran',
                        style: AppTypography.titleSmall.copyWith(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: CityWalletUi.primaryColor,
                        ),
                      ),
                    ),
                    Text(
                      formatRupiah(totalPay),
                      style: AppTypography.headline2.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: CityWalletUi.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: CityWalletUi.bodyStyle(context).copyWith(fontSize: 12.5),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: CityWalletUi.cardTitleStyle(context).copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: valueColor ?? CityWalletUi.ink(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
