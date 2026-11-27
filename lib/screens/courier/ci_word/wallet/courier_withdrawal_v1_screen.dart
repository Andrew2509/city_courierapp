import 'package:city_courierapp/core/config/app_typography.dart';
import 'package:city_courierapp/core/utils/currency_format.dart';
import 'package:city_courierapp/models/wallet/wallet_models.dart';
import 'package:city_courierapp/screens/courier/ci_word/wallet/courier_payout_detail_screen.dart';
import 'package:city_courierapp/screens/profile/keamanan_akun/widgets/transaction_pin_prompt_sheet.dart';
import 'package:city_courierapp/screens/wallet/widgets/wallet_ui_components.dart';
import 'package:city_courierapp/services/security/transaction_security_guard.dart';
import 'package:city_courierapp/services/wallet/courier_wallet_v1_service.dart';
import 'package:city_courierapp/widgets/payment/payment_brand_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Tarik Saldo Kurir berbasis Wallet v1 dengan tampilan 4-langkah yang seragam
/// dengan `CustomerWithdrawalScreen` (`CityWalletUi`).
class CourierWithdrawalV1Screen extends StatefulWidget {
  final CourierWalletV1Service? service;

  const CourierWithdrawalV1Screen({
    super.key,
    this.service,
  });

  @override
  State<CourierWithdrawalV1Screen> createState() =>
      _CourierWithdrawalV1ScreenState();
}

class _CourierWithdrawalV1ScreenState extends State<CourierWithdrawalV1Screen> {
  static const List<(String, String)> _defaultBankChannels = [
    ('ID_BCA', 'Bank BCA'),
    ('ID_BRI', 'Bank BRI'),
    ('ID_BNI', 'Bank BNI'),
    ('ID_MANDIRI', 'Bank Mandiri'),
    ('ID_PERMATA', 'Bank Permata'),
    ('ID_CIMB', 'Bank CIMB Niaga'),
    ('ID_BSI', 'Bank Syariah Indonesia (BSI)'),
  ];

  static const List<(String, String)> _defaultEwalletChannels = [
    ('ID_DANA', 'DANA'),
    ('ID_OVO', 'OVO'),
    ('ID_GOPAY', 'GoPay'),
    ('ID_SHOPEEPAY', 'ShopeePay'),
    ('ID_LINKAJA', 'LinkAja'),
  ];

  late final CourierWalletV1Service _service =
      widget.service ?? CourierWalletV1Service.instance;

  final TextEditingController _numberCtrl = TextEditingController();
  final TextEditingController _holderCtrl = TextEditingController();
  final TextEditingController _amountCtrl = TextEditingController();
  late final DestinationNameInquiryController _inquiry =
      DestinationNameInquiryController(
    inquireFn: _service.inquireDestination,
  );

  CourierWalletV1Summary? _summary;
  List<(String, String)> _bankChannels = _defaultBankChannels;
  List<(String, String)> _ewalletChannels = _defaultEwalletChannels;
  List<PayoutDestinationV1> _destinations = [];
  List<PayoutTransactionV1> _history = [];
  PayoutDestinationV1? _selectedDest;
  String _selectedType = 'bank';
  String _selectedChannelCode = _defaultBankChannels.first.$1;
  bool _addingNewDestination = false;
  bool _showManualNameField = false;

  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _inquiry.addListener(_onInquiryUpdated);
    _load();
  }

  @override
  void dispose() {
    _inquiry.removeListener(_onInquiryUpdated);
    _inquiry.dispose();
    _numberCtrl.dispose();
    _holderCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  void _onInquiryUpdated() {
    if (mounted) setState(() {});
  }

  bool _isEwallet(PayoutDestinationV1 d) =>
      d.destinationType.toLowerCase().contains('wallet');

  List<(String, String)> get _activeChannels =>
      _selectedType == 'ewallet' ? _ewalletChannels : _bankChannels;

  List<PayoutDestinationV1> get _savedForCurrentType => _destinations
      .where((d) => _selectedType == 'ewallet' ? _isEwallet(d) : !_isEwallet(d))
      .toList();

  bool get _usingSavedDest =>
      !_addingNewDestination &&
      _selectedDest != null &&
      _accountDigits.isEmpty;

  String get _selectedChannelLabel {
    if (_usingSavedDest && _selectedDest != null) {
      return _selectedDest!.channelName.isNotEmpty
          ? _selectedDest!.channelName
          : _selectedDest!.channelCode;
    }
    for (final c in _activeChannels) {
      if (c.$1 == _selectedChannelCode) return c.$2;
    }
    return _selectedChannelCode;
  }

  String get _accountDigits =>
      _numberCtrl.text.replaceAll(RegExp(r'[^\d]'), '');

  int get _parsedAmount {
    final digits = _amountCtrl.text.replaceAll(RegExp(r'[^\d]'), '');
    return int.tryParse(digits) ?? 0;
  }

  String? _matchChannelCode(String rawCode, String type) {
    final channels = type == 'ewallet' ? _ewalletChannels : _bankChannels;
    final norm = rawCode.trim().toUpperCase();
    for (final c in channels) {
      if (c.$1 == norm || c.$1.replaceFirst('ID_', '') == norm) {
        return c.$1;
      }
    }
    return null;
  }

  void _scheduleInquiry() {
    _inquiry.schedule(
      destinationType: _selectedType,
      channelCode: _selectedChannelCode,
      rawNumber: _numberCtrl.text,
      holderController: _holderCtrl,
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _service.getWallet(),
        _service.getDestinationsBundle(),
        _service.getPayouts(),
      ]);
      if (!mounted) return;
      final summary = results[0] as CourierWalletV1Summary;
      final bundle = results[1] as PayoutDestinationsBundle;
      final payouts = results[2]
          as ({
            CourierAutoPayoutStatusV1 autoPayoutStatus,
            List<PayoutTransactionV1> items,
          });

      final nextBanks =
          bundle.hasServerChannels ? bundle.bankChannels : _defaultBankChannels;
      final nextEwallets = bundle.hasServerChannels
          ? bundle.ewalletChannels
          : _defaultEwalletChannels;
      final dests = bundle.items;
      final defaultDest = dests.isNotEmpty
          ? dests.firstWhere((d) => d.isDefault, orElse: () => dests.first)
          : null;
      final resolvedType = defaultDest != null
          ? (_isEwallet(defaultDest) ? 'ewallet' : 'bank')
          : _selectedType;
      final matching = dests
          .where(
            (d) => resolvedType == 'ewallet' ? _isEwallet(d) : !_isEwallet(d),
          )
          .toList();
      final savedDest = matching.isNotEmpty
          ? matching.firstWhere(
              (d) => d.isDefault,
              orElse: () => matching.first,
            )
          : null;
      final channels = resolvedType == 'ewallet' ? nextEwallets : nextBanks;

      setState(() {
        _summary = summary;
        _bankChannels = nextBanks;
        _ewalletChannels = nextEwallets;
        _destinations = dests;
        _selectedType = resolvedType;
        _selectedDest = savedDest;
        _addingNewDestination = savedDest == null;
        final matchedCode = savedDest != null
            ? _matchChannelCode(savedDest.channelCode, resolvedType)
            : null;
        _selectedChannelCode =
            matchedCode ?? (channels.isNotEmpty ? channels.first.$1 : '');
        if (savedDest != null && _numberCtrl.text.trim().isEmpty) {
          _holderCtrl.text = savedDest.accountHolderName;
        }
        _history = payouts.items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _selectType(String type) {
    if (_selectedType == type) return;
    final channels = type == 'ewallet' ? _ewalletChannels : _bankChannels;
    final matching = _destinations
        .where((d) => type == 'ewallet' ? _isEwallet(d) : !_isEwallet(d))
        .toList();
    final savedDest = matching.isNotEmpty
        ? matching.firstWhere((d) => d.isDefault, orElse: () => matching.first)
        : null;
    final matchedCode =
        savedDest != null ? _matchChannelCode(savedDest.channelCode, type) : null;

    setState(() {
      _selectedType = type;
      _selectedDest = savedDest;
      _addingNewDestination = savedDest == null;
      _selectedChannelCode =
          matchedCode ?? (channels.isNotEmpty ? channels.first.$1 : '');
      _numberCtrl.clear();
      _holderCtrl.text = savedDest?.accountHolderName ?? '';
      _showManualNameField = false;
      _inquiry.reset();
    });
  }

  void _applySavedDestination(PayoutDestinationV1 dest) {
    final matchedCode = _matchChannelCode(dest.channelCode, _selectedType);
    setState(() {
      _selectedDest = dest;
      _addingNewDestination = false;
      if (matchedCode != null) {
        _selectedChannelCode = matchedCode;
      }
      _numberCtrl.clear();
      _holderCtrl.text = dest.accountHolderName;
      _showManualNameField = false;
      _inquiry.reset();
    });
  }

  void _enableNewDestinationInput() {
    setState(() {
      _addingNewDestination = true;
      _selectedDest = null;
      _numberCtrl.clear();
      _holderCtrl.clear();
      _showManualNameField = false;
      _inquiry.reset();
    });
  }

  String? get _validationError {
    final summary = _summary;
    if (summary == null) return 'Data dompet belum dimuat.';
    if (summary.isFrozen) {
      return summary.freezeReason ?? 'Dompet sementara dibekukan oleh Admin.';
    }
    if (!summary.payoutProviderEnabled) {
      return 'Layanan pencairan (${summary.activePayoutProvider.toUpperCase()}) sedang dinonaktifkan oleh Admin.';
    }
    if (!_usingSavedDest && _accountDigits.length < 6) {
      return _selectedType == 'ewallet'
          ? 'Masukkan nomor telepon e-wallet minimal 6 digit.'
          : 'Masukkan nomor rekening bank minimal 6 digit.';
    }
    final amount = _parsedAmount;
    if (amount <= 0) return 'Masukkan nominal penarikan.';
    if (amount < summary.minPayoutIdr) {
      return 'Minimal penarikan ${formatRupiah(summary.minPayoutIdr)}.';
    }
    if (amount > summary.maxPayoutIdr) {
      return 'Maksimal penarikan ${formatRupiah(summary.maxPayoutIdr)}.';
    }
    if (amount > summary.availableBalance) {
      return 'Saldo tersedia tidak mencukupi.';
    }
    if (amount - summary.feeIdr <= 0) {
      return 'Nominal harus lebih besar dari biaya admin.';
    }
    return null;
  }

  void _setQuickAmount(int value) {
    setState(() {
      _amountCtrl.text = RupiahDigitsInputFormatter.formatDigits(value);
    });
  }

  Future<void> _submit() async {
    final summary = _summary;
    if (summary == null) return;

    final usingSaved = _usingSavedDest;
    final digits = _accountDigits;
    final amount = _parsedAmount;
    final isEwallet = _selectedType == 'ewallet';

    if (!usingSaved && digits.length < 6) {
      CityWalletUi.showSnackBar(
        context,
        isEwallet
            ? 'Masukkan nomor telepon e-wallet dengan valid.'
            : 'Masukkan nomor rekening tujuan dengan valid.',
      );
      return;
    }

    if (amount < summary.minPayoutIdr ||
        amount > summary.maxPayoutIdr ||
        amount > summary.availableBalance) {
      CityWalletUi.showSnackBar(
        context,
        'Nominal harus minimal ${formatRupiah(summary.minPayoutIdr)} dan tidak melebihi saldo tersedia.',
      );
      return;
    }

    String resolvedHolder = _holderCtrl.text.trim();
    if (!usingSaved && resolvedHolder.isEmpty) {
      try {
        final inquiry = await _service.inquireDestination(
          destinationType: _selectedType,
          channelCode: _selectedChannelCode,
          accountNumber: digits,
        );
        if (!mounted) return;
        if (inquiry.found && inquiry.accountHolderName != null) {
          resolvedHolder = inquiry.accountHolderName!.trim();
          _holderCtrl.text = resolvedHolder;
        }
      } catch (_) {
        // Biarkan pengguna mengisi nama secara manual bila inquiry gagal.
      }
      if (!mounted) return;
      if (resolvedHolder.isEmpty) {
        setState(() => _showManualNameField = true);
        CityWalletUi.showSnackBar(
          context,
          'Masukkan nama pemilik akun terlebih dahulu.',
        );
        return;
      }
    }

    setState(() => _submitting = true);
    int? resolvedDestId;
    try {
      final auth = await TransactionSecurityGuard.authorize(
        context,
        biometricEnabled: summary.biometricEnabled,
        hasTransactionPin: summary.hasTransactionPin,
        biometricReason:
            'Verifikasi sidik jari atau wajah untuk menarik saldo kurir',
        pinSubtitle: 'Masukkan 6 digit PIN transaksi untuk menarik saldo.',
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

      if (usingSaved) {
        resolvedDestId = _selectedDest!.id;
      } else {
        final created = await _service.addDestination(
          destinationType: _selectedType,
          channelCode: _selectedChannelCode,
          accountNumber: digits,
          accountHolderName: resolvedHolder,
          isDefault: true,
        );
        resolvedDestId = created.id;
      }

      final payout = await _service.requestWithdrawal(
        amount: amount,
        destinationId: resolvedDestId,
        transactionPin: auth.pin,
      );
      if (!mounted) return;
      await _handleWithdrawalSubmitted(payout);
    } on WalletApiException catch (e) {
      if (e.errorCode == 'TRANSACTION_PIN_REQUIRED' &&
          mounted &&
          resolvedDestId != null) {
        setState(() => _submitting = false);
        final prompted = await TransactionPinPromptSheet.show(
          context,
          subtitle:
              'Masukkan 6 digit PIN transaksi untuk mengonfirmasi penarikan.',
        );
        if (prompted == null || !mounted) return;
        setState(() => _submitting = true);
        try {
          final payout = await _service.requestWithdrawal(
            amount: amount,
            destinationId: resolvedDestId,
            transactionPin: prompted,
          );
          if (!mounted) return;
          await _handleWithdrawalSubmitted(payout);
          return;
        } catch (err) {
          if (!mounted) return;
          CityWalletUi.showSnackBar(
            context,
            err.toString(),
            backgroundColor: CityWalletUi.errorRed,
          );
          return;
        }
      }
      if (!mounted) return;
      CityWalletUi.showSnackBar(
        context,
        e.toString(),
        backgroundColor: CityWalletUi.errorRed,
      );
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

  Future<void> _handleWithdrawalSubmitted(PayoutTransactionV1 payout) async {
    _amountCtrl.clear();
    _numberCtrl.clear();
    _holderCtrl.clear();
    _inquiry.reset();
    _showManualNameField = false;
    CityWalletUi.showWithdrawalOutcomeSnackBar(context, payout);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    final blocked = summary != null &&
        (summary.isFrozen || !summary.payoutProviderEnabled);

    return Scaffold(
      backgroundColor: CityWalletUi.scaffoldBg(context),
      appBar: CityWalletUi.buildAppBar(context, title: 'Tarik Saldo'),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: CityWalletUi.primaryColor,
                    ),
                  )
                : _error != null
                    ? WalletErrorState(message: _error!, onRetry: _load)
                    : RefreshIndicator(
                        color: CityWalletUi.primaryColor,
                        onRefresh: _load,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (blocked) _buildLockedBanner(summary),
                              _buildBalanceCard(summary),
                              const SizedBox(height: 16),
                              _buildDestinationTypeSection(),
                              const SizedBox(height: 16),
                              _buildDestinationInfoSection(blocked),
                              const SizedBox(height: 16),
                              _buildAmountSection(summary, blocked),
                              const SizedBox(height: 16),
                              _buildSummarySection(summary),
                              const SizedBox(height: 20),
                              _buildHistorySection(),
                            ],
                          ),
                        ),
                      ),
          ),
          if (!_loading && _error == null)
            CityWalletUi.stickyBottomBar(
              context,
              securityIcon: Icons.verified_user_outlined,
              securityNote:
                  'Saldo dipotong aman saat pengajuan dibuat; status pencairan diperbarui otomatis.',
              child: ElevatedButton(
                onPressed: (blocked || _submitting) ? null : _submit,
                style: CityWalletUi.primaryButtonStyle(
                  enabled: !blocked && !_submitting,
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
                    : Text(
                        blocked
                            ? (summary.isFrozen
                                ? 'Dompet Dibekukan'
                                : 'Gateway Pencairan Dinonaktifkan')
                            : 'Ajukan Penarikan',
                      ),
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

  Widget _buildLockedBanner(CourierWalletV1Summary summary) {
    final isFrozen = summary.isFrozen;
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF59E0B)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isFrozen ? Icons.ac_unit_rounded : Icons.lock_outline_rounded,
            color: const Color(0xFFB45309),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isFrozen
                      ? 'Dompet Dibekukan'
                      : 'Gateway Pencairan Dinonaktifkan',
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                    color: const Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isFrozen
                      ? (summary.freezeReason ??
                          'Penarikan sementara ditahan. Hubungi Admin City Courier.')
                      : 'Layanan pencairan (${summary.activePayoutProvider.toUpperCase()}) sedang dinonaktifkan oleh Admin.',
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
    );
  }

  Widget _buildBalanceCard(CourierWalletV1Summary? summary) {
    final available = summary?.availableBalance ?? 0;
    final pending = summary?.pendingBalance ?? 0;
    final reserved = summary?.reservedBalance ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Saldo tersedia',
                        style: AppTypography.caption.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                    if (summary != null) ...[
                      const SizedBox(width: 8),
                      EnvironmentModeBadge(
                        mode: summary.mode,
                        isSimulated: summary.isSandboxOrDemo,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    formatRupiah(available),
                    style: AppTypography.headline1.copyWith(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
                if (pending > 0 || reserved > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    reserved > 0
                        ? 'Dalam proses pencairan: ${formatRupiah(reserved)}'
                        : 'Dalam proses settlement: ${formatRupiah(pending)}',
                    style: AppTypography.caption.copyWith(
                      fontSize: 11.5,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          const WalletHeroIllustration(),
        ],
      ),
    );
  }

  Widget _buildDestinationTypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeader('1', 'Pilih Tujuan Penarikan'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _typeOptionCard(
                label: 'Rekening Bank',
                icon: Icons.account_balance_rounded,
                selected: _selectedType == 'bank',
                onTap: () => _selectType('bank'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _typeOptionCard(
                label: 'E-Wallet',
                icon: Icons.account_balance_wallet_rounded,
                selected: _selectedType == 'ewallet',
                onTap: () => _selectType('ewallet'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _typeOptionCard({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final dark = CityWalletUi.isDark(context);
    return Material(
      color: selected
          ? (dark
              ? CityWalletUi.primaryColor.withValues(alpha: 0.16)
              : const Color(0xFFFFF5EE))
          : CityWalletUi.cardBg(context),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? CityWalletUi.primaryColor
                  : CityWalletUi.lineColor(context),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: CityWalletUi.primaryColor.withValues(
                    alpha: selected ? 0.14 : 0.1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 17,
                  color: CityWalletUi.primaryColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: CityWalletUi.ink(context),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected
                        ? CityWalletUi.primaryColor
                        : CityWalletUi.mutedInk(context),
                    width: 1.6,
                  ),
                ),
                alignment: Alignment.center,
                child: selected
                    ? Container(
                        width: 9,
                        height: 9,
                        decoration: const BoxDecoration(
                          color: CityWalletUi.primaryColor,
                          shape: BoxShape.circle,
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDestinationInfoSection(bool blocked) {
    final isEwallet = _selectedType == 'ewallet';
    final channels = _activeChannels;
    final savedList = _savedForCurrentType;
    final shouldShowNameInput = _showManualNameField ||
        _accountDigits.length >= 6 ||
        (_inquiry.result != null && !_inquiry.result!.found) ||
        _inquiry.errorMessage != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeader('2', 'Masukkan Informasi Tujuan'),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: CityWalletUi.cardDecoration(context, radius: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (savedList.isNotEmpty) ...[
                Text(
                  'Tujuan tersimpan',
                  style: AppTypography.caption.copyWith(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: CityWalletUi.secondaryInk(context),
                  ),
                ),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final d in savedList)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(
                              '${d.channelName.isNotEmpty ? d.channelName : d.channelCode}'
                              '${d.accountNumberMasked.isNotEmpty ? ' • ${d.accountNumberMasked}' : ''}',
                              style: AppTypography.caption.copyWith(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: (!_addingNewDestination &&
                                        _selectedDest?.id == d.id)
                                    ? CityWalletUi.primaryColor
                                    : CityWalletUi.ink(context),
                              ),
                            ),
                            selected: !_addingNewDestination &&
                                _selectedDest?.id == d.id,
                            showCheckmark: false,
                            selectedColor: CityWalletUi.primaryColor
                                .withValues(alpha: 0.1),
                            backgroundColor: CityWalletUi.subtleBg(context),
                            side: BorderSide(
                              color: (!_addingNewDestination &&
                                      _selectedDest?.id == d.id)
                                  ? CityWalletUi.primaryColor
                                  : CityWalletUi.lineColor(context),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            onSelected: blocked
                                ? null
                                : (_) => _applySavedDestination(d),
                          ),
                        ),
                      ChoiceChip(
                        label: Text(
                          '+ Tujuan Baru',
                          style: AppTypography.caption.copyWith(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: _addingNewDestination
                                ? CityWalletUi.primaryColor
                                : CityWalletUi.ink(context),
                          ),
                        ),
                        selected: _addingNewDestination,
                        showCheckmark: false,
                        selectedColor:
                            CityWalletUi.primaryColor.withValues(alpha: 0.1),
                        backgroundColor: CityWalletUi.subtleBg(context),
                        side: BorderSide(
                          color: _addingNewDestination
                              ? CityWalletUi.primaryColor
                              : CityWalletUi.lineColor(context),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        onSelected: blocked
                            ? null
                            : (_) => _enableNewDestinationInput(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (!_addingNewDestination && _selectedDest != null) ...[
                _buildSelectedSavedCard(_selectedDest!),
              ] else ...[
                Text(
                  isEwallet ? 'Pilih E-Wallet' : 'Pilih Bank',
                  style: AppTypography.caption.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: CityWalletUi.secondaryInk(context),
                  ),
                ),
                const SizedBox(height: 6),
                if (channels.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: CityWalletUi.subtleBg(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: CityWalletUi.lineColor(context)),
                    ),
                    child: Text(
                      isEwallet
                          ? 'Tidak tersedia — tidak ada saluran e-wallet yang didukung saat ini.'
                          : 'Tidak tersedia — tidak ada bank tujuan yang didukung saat ini.',
                      style: CityWalletUi.captionStyle(context).copyWith(
                        fontSize: 12,
                        color: CityWalletUi.secondaryInk(context),
                      ),
                    ),
                  )
                else
                  DropdownButtonFormField<String>(
                    key: ValueKey('chan_${_selectedType}_$_selectedChannelCode'),
                    initialValue: channels.any((c) => c.$1 == _selectedChannelCode)
                        ? _selectedChannelCode
                        : channels.first.$1,
                    isExpanded: true,
                    dropdownColor: CityWalletUi.cardBg(context),
                    icon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: CityWalletUi.secondaryInk(context),
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: CityWalletUi.cardBg(context),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: CityWalletUi.lineColor(context),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: CityWalletUi.lineColor(context),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: CityWalletUi.primaryColor,
                          width: 1.5,
                        ),
                      ),
                    ),
                    items: channels
                        .map(
                          (c) => DropdownMenuItem<String>(
                            value: c.$1,
                            child: Row(
                              children: [
                                PaymentBrandLogo(
                                  method: c.$2,
                                  size: 28,
                                  width: 44,
                                  borderRadius: 6,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    c.$2,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: CityWalletUi.cardTitleStyle(context)
                                        .copyWith(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: blocked
                        ? null
                        : (val) {
                            if (val == null) return;
                            setState(() {
                              _selectedChannelCode = val;
                            });
                            _scheduleInquiry();
                          },
                  ),
                const SizedBox(height: 12),
                Text(
                  isEwallet ? 'Nomor Telepon E-Wallet' : 'Nomor Rekening',
                  style: AppTypography.caption.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: CityWalletUi.secondaryInk(context),
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _numberCtrl,
                  enabled: !blocked,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => _scheduleInquiry(),
                  style: AppTypography.bodyMedium.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: CityWalletUi.ink(context),
                  ),
                  decoration: CityWalletUi.inputDecoration(
                    context: context,
                    hintText: isEwallet
                        ? 'Masukkan nomor telepon e-wallet'
                        : 'Masukkan nomor rekening',
                  ),
                ),
                DestinationInquiryStatusBanner(
                  controller: _inquiry,
                  onUseDetectedName: () => _inquiry.restoreAutoFill(_holderCtrl),
                ),
                if (shouldShowNameInput) ...[
                  const SizedBox(height: 12),
                  CityWalletUi.fieldLabel(
                    isEwallet ? 'Nama Pemilik Akun' : 'Nama Pemilik Rekening',
                    context: context,
                    trailing: WalletStatusChip(
                      status: _inquiry.hasAutoFilled
                          ? 'auto_verified'
                          : (_inquiry.result?.verificationStatus ??
                              'unverified'),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _holderCtrl,
                    enabled: !blocked,
                    textCapitalization: TextCapitalization.characters,
                    onChanged: (val) => _inquiry.onManualNameEdited(val),
                    style: AppTypography.bodySmall.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: CityWalletUi.ink(context),
                    ),
                    decoration: CityWalletUi.inputDecoration(
                      context: context,
                      hintText: 'Nama pemilik sesuai akun',
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedSavedCard(PayoutDestinationV1 dest) {
    final brandLabel =
        dest.channelName.isNotEmpty ? dest.channelName : dest.channelCode;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CityWalletUi.subtleBg(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CityWalletUi.lineColor(context)),
      ),
      child: Row(
        children: [
          PaymentBrandLogo(
            method: brandLabel,
            size: 32,
            width: 48,
            borderRadius: 8,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$brandLabel • ${dest.accountNumberMasked}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: CityWalletUi.cardTitleStyle(context).copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  dest.accountHolderName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: CityWalletUi.bodyStyle(context).copyWith(
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          WalletStatusChip(status: dest.normalizedVerificationStatus),
        ],
      ),
    );
  }

  Widget _buildAmountSection(CourierWalletV1Summary? summary, bool blocked) {
    final available = summary?.availableBalance ?? 0;
    final min = summary?.minPayoutIdr ?? 20000;
    final max = summary?.maxPayoutIdr ?? 5000000;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeader('3', 'Nominal Penarikan'),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: CityWalletUi.cardBg(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: CityWalletUi.lineColor(context)),
          ),
          clipBehavior: Clip.antiAlias,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: CityWalletUi.subtleBg(context),
                    border: Border(
                      right: BorderSide(
                        color: CityWalletUi.lineColor(context),
                      ),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Rp',
                    style: AppTypography.titleSmall.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: CityWalletUi.secondaryInk(context),
                    ),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _amountCtrl,
                    enabled: !blocked,
                    keyboardType: TextInputType.number,
                    inputFormatters: const [RupiahDigitsInputFormatter()],
                    onChanged: (_) => setState(() {}),
                    style: AppTypography.titleMedium.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: CityWalletUi.ink(context),
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      hintText: 'Masukkan nominal penarikan',
                      hintStyle: AppTypography.bodyMedium.copyWith(
                        fontSize: 14,
                        color: CityWalletUi.mutedInk(context),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Minimal ${formatRupiah(min)} • Maksimal ${formatRupiah(max)}',
          style: CityWalletUi.captionStyle(context).copyWith(fontSize: 11.5),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (available >= min) _quickChip('Tarik semua', available, blocked),
            if (available >= 50000) _quickChip('Rp 50.000', 50000, blocked),
            if (available >= 100000) _quickChip('Rp 100.000', 100000, blocked),
            if (available >= 500000) _quickChip('Rp 500.000', 500000, blocked),
          ],
        ),
      ],
    );
  }

  Widget _quickChip(String label, int value, bool blocked) {
    final enabled = value > 0 && !blocked;
    final selected = _parsedAmount == value && value > 0;
    return ActionChip(
      label: Text(
        label,
        style: AppTypography.caption.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: !enabled
              ? CityWalletUi.mutedInk(context)
              : (selected
                  ? CityWalletUi.primaryColor
                  : CityWalletUi.secondaryInk(context)),
        ),
      ),
      backgroundColor: selected
          ? CityWalletUi.primaryColor.withValues(alpha: 0.10)
          : CityWalletUi.cardBg(context),
      side: BorderSide(
        color: selected
            ? CityWalletUi.primaryColor
            : CityWalletUi.lineColor(context),
        width: selected ? 1.5 : 1,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onPressed: enabled ? () => _setQuickAmount(value) : null,
    );
  }

  Widget _buildSummarySection(CourierWalletV1Summary? summary) {
    final amount = _parsedAmount;
    final fee = summary?.feeIdr ?? 0;
    final net = amount > fee ? amount - fee : 0;
    final isEwallet = _selectedType == 'ewallet';
    final displayNumber = _accountDigits.isNotEmpty
        ? _accountDigits
        : (_selectedDest != null && _selectedDest!.accountNumberMasked.isNotEmpty
            ? _selectedDest!.accountNumberMasked
            : '-');
    final holderName = _holderCtrl.text.trim().isNotEmpty
        ? _holderCtrl.text.trim()
        : (_selectedDest?.accountHolderName ?? '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeader('4', 'Konfirmasi Penarikan'),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: CityWalletUi.cardDecoration(context, radius: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _summaryRow(
                'Tujuan Penarikan',
                isEwallet ? 'E-Wallet' : 'Rekening Bank',
              ),
              _summaryRow(
                isEwallet ? 'E-Wallet' : 'Bank',
                _selectedChannelLabel,
              ),
              _summaryRow(
                isEwallet ? 'Nomor Telepon' : 'Nomor Rekening',
                displayNumber,
              ),
              if (holderName.isNotEmpty) _summaryRow('Atas Nama', holderName),
              _summaryRow('Biaya Admin', fee == 0 ? 'Gratis' : formatRupiah(fee)),
              if (fee > 0 && amount > 0)
                _summaryRow('Total Diterima', formatRupiah(net)),
              if (amount > 0 && _validationError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _validationError!,
                  style: AppTypography.caption.copyWith(
                    fontSize: 11.5,
                    color: CityWalletUi.errorRed,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: CityWalletUi.isDark(context)
                      ? CityWalletUi.primaryColor.withValues(alpha: 0.16)
                      : const Color(0xFFFFF3E8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Nominal Penarikan',
                        style: AppTypography.titleSmall.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: CityWalletUi.primaryColor,
                        ),
                      ),
                    ),
                    Text(
                      formatRupiah(amount),
                      style: AppTypography.headline2.copyWith(
                        fontSize: 19,
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

  Widget _summaryRow(String label, String value) {
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
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Riwayat Penarikan',
          style: CityWalletUi.sectionTitleStyle(context),
        ),
        const SizedBox(height: 10),
        if (_history.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
            decoration: CityWalletUi.cardDecoration(context, radius: 16),
            child: Column(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 34,
                  color: CityWalletUi.mutedInk(context),
                ),
                const SizedBox(height: 8),
                Text(
                  'Belum ada riwayat penarikan.',
                  style: CityWalletUi.bodyStyle(context).copyWith(
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          )
        else
          ..._history.map(
            (w) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: CityWalletUi.cardDecoration(context, radius: 14),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CourierPayoutDetailScreen(
                        payoutId: w.id,
                        service: _service,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                formatRupiah(w.amount),
                                style: CityWalletUi.cardTitleStyle(context),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${w.channelCode} • ${w.accountNumberMasked}\n${w.reference}',
                                style: CityWalletUi.bodyStyle(context).copyWith(
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        WalletStatusChip(status: w.status),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: CityWalletUi.mutedInk(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
