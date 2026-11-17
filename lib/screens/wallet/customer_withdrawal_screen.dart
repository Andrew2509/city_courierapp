import 'package:city_courierapp/core/config/app_colors.dart';
import 'package:city_courierapp/core/utils/currency_format.dart';
import 'package:city_courierapp/models/wallet/wallet_models.dart';
import 'package:city_courierapp/screens/profile/keamanan_akun/widgets/transaction_pin_prompt_sheet.dart';
import 'package:city_courierapp/screens/wallet/payout_destinations_screen.dart';
import 'package:city_courierapp/screens/wallet/widgets/wallet_ui_components.dart';
import 'package:city_courierapp/services/wallet/customer_wallet_service.dart';
import 'package:flutter/material.dart';

class CustomerWithdrawalScreen extends StatefulWidget {
  final CustomerWalletSummary wallet;
  final CustomerWalletService? service;

  const CustomerWithdrawalScreen({
    super.key,
    required this.wallet,
    this.service,
  });

  @override
  State<CustomerWithdrawalScreen> createState() =>
      _CustomerWithdrawalScreenState();
}

class _CustomerWithdrawalScreenState extends State<CustomerWithdrawalScreen> {
  late final CustomerWalletService _service =
      widget.service ?? CustomerWalletService.instance;
  final TextEditingController _amountCtrl = TextEditingController();
  List<PayoutDestinationV1> _destinations = [];
  List<PayoutTransactionV1> _history = [];
  PayoutDestinationV1? _selectedDest;
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  int get _parsedAmount {
    final digits = _amountCtrl.text.replaceAll(RegExp(r'[^\d]'), '');
    return int.tryParse(digits) ?? 0;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _service.getDestinations(),
        _service.getWithdrawals(),
      ]);
      if (!mounted) return;
      final dests = results[0] as List<PayoutDestinationV1>;
      setState(() {
        _destinations = dests;
        _selectedDest = dests.isNotEmpty
            ? dests.firstWhere((d) => d.isDefault, orElse: () => dests.first)
            : null;
        _history = results[1] as List<PayoutTransactionV1>;
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

  String? get _validationError {
    if (!widget.wallet.withdrawalEnabled) {
      return widget.wallet.withdrawalBlockedReason ??
          'Penarikan dana saat ini tidak tersedia.';
    }
    if (_selectedDest == null) {
      return 'Tambahkan rekening atau e-wallet tujuan terlebih dahulu.';
    }
    final amount = _parsedAmount;
    if (amount <= 0) return 'Masukkan nominal penarikan.';
    if (amount < widget.wallet.withdrawalMinIdr) {
      return 'Minimal penarikan ${formatRupiah(widget.wallet.withdrawalMinIdr)}.';
    }
    if (amount > widget.wallet.withdrawalMaxIdr) {
      return 'Maksimal penarikan ${formatRupiah(widget.wallet.withdrawalMaxIdr)}.';
    }
    if (amount > widget.wallet.availableBalance) {
      return 'Saldo tersedia tidak mencukupi.';
    }
    return null;
  }

  void _setQuickAmount(int value) {
    setState(() {
      _amountCtrl.text = RupiahDigitsInputFormatter.formatDigits(value);
    });
  }

  Future<void> _openDestinations() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PayoutDestinationsScreen(service: _service),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _submit() async {
    final dest = _selectedDest;
    final amount = _parsedAmount;
    if (dest == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tambahkan rekening/e-wallet tujuan terlebih dahulu.'),
        ),
      );
      return;
    }
    if (amount < widget.wallet.withdrawalMinIdr ||
        amount > widget.wallet.availableBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Nominal harus minimal ${formatRupiah(widget.wallet.withdrawalMinIdr)} dan tidak melebihi saldo tersedia.',
          ),
        ),
      );
      return;
    }

    String? pin;
    if (widget.wallet.hasTransactionPin) {
      pin = await TransactionPinPromptSheet.show(
        context,
        subtitle:
            'Masukkan 6 digit PIN untuk mengonfirmasi penarikan saldo.',
      );
      if (pin == null || !mounted) return;
    }

    setState(() => _submitting = true);
    try {
      await _service.requestWithdrawal(
        amount: amount,
        destinationId: dest.id,
        transactionPin: pin,
      );
      if (!mounted) return;
      _amountCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Permintaan penarikan dana berhasil dikirim.'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
      _load();
    } on WalletApiException catch (e) {
      if (e.errorCode == 'TRANSACTION_PIN_REQUIRED' && mounted) {
        setState(() => _submitting = false);
        final prompted = await TransactionPinPromptSheet.show(
          context,
          subtitle:
              'Masukkan 6 digit PIN untuk mengonfirmasi penarikan saldo.',
        );
        if (prompted == null || !mounted) return;
        setState(() => _submitting = true);
        try {
          await _service.requestWithdrawal(
            amount: amount,
            destinationId: dest.id,
            transactionPin: prompted,
          );
          if (!mounted) return;
          _amountCtrl.clear();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permintaan penarikan dana berhasil dikirim.'),
              backgroundColor: Color(0xFF16A34A),
            ),
          );
          _load();
          return;
        } catch (err) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(err.toString()),
              backgroundColor: CityWalletUi.errorRed,
            ),
          );
          return;
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: CityWalletUi.errorRed,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: CityWalletUi.errorRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = !widget.wallet.withdrawalEnabled;

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            CityWalletUi.buildHeader(
              context,
              title: 'Tarik Dana',
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryOrange,
                      ),
                    )
                  : _error != null
                      ? WalletErrorState(message: _error!, onRetry: _load)
                      : RefreshIndicator(
                          color: AppColors.primaryOrange,
                          onRefresh: _load,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                            children: [
                              if (locked) _buildLockedBanner(),
                              _buildBalanceCard(),
                              const SizedBox(height: 20),
                              _buildDestinationSection(locked),
                              const SizedBox(height: 20),
                              _buildAmountSection(locked),
                              const SizedBox(height: 20),
                              _buildSummaryCard(),
                              const SizedBox(height: 24),
                              _buildHistorySection(),
                            ],
                          ),
                        ),
            ),
            if (!_loading && _error == null)
              CityWalletUi.stickyBottomBar(
                context,
                securityNote:
                    'Dana ditarik ke rekening/e-wallet terverifikasi sesuai kebijakan layanan.',
                child: ElevatedButton(
                  onPressed: (locked || _submitting) ? null : _submit,
                  style: CityWalletUi.primaryButtonStyle(
                    enabled: !locked && !_submitting,
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
                          locked
                              ? (!widget.wallet.withdrawalProviderEnabled
                                  ? 'Gateway Pencairan Dinonaktifkan'
                                  : 'Tidak Tersedia di Production')
                              : 'Ajukan Penarikan',
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLockedBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF59E0B)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline_rounded, color: Color(0xFFB45309)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  !widget.wallet.withdrawalProviderEnabled
                      ? 'Gateway Pencairan Dinonaktifkan'
                      : 'Fitur Penarikan Terkunci di Production',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.wallet.withdrawalBlockedReason ??
                      'Penarikan wallet pelanggan menunggu persetujuan regulasi & penyedia pembayaran.',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF78350F)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryOrange,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Saldo tersedia',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ),
              EnvironmentModeBadge(
                mode: widget.wallet.mode,
                isSimulated: widget.wallet.isSandboxOrDemo,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            formatRupiah(widget.wallet.availableBalance),
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDestinationSection(bool locked) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CityWalletUi.fieldLabel(
          'Rekening Tujuan',
          trailing: TextButton(
            onPressed: _openDestinations,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryOrange,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Kelola Rekening',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (_destinations.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: CityWalletUi.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Belum ada rekening bank atau e-wallet tujuan.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: CityWalletUi.inkSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _openDestinations,
                  style: CityWalletUi.secondaryButtonStyle(
                    borderTint: AppColors.primaryOrange.withValues(alpha: 0.45),
                    fgColor: AppColors.primaryOrange,
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text(
                    'Tambah Rekening / E-Wallet',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          )
        else
          DropdownButtonFormField<int>(
            initialValue: _selectedDest?.id,
            isExpanded: true,
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: CityWalletUi.inkSecondary,
            ),
            decoration: CityWalletUi.inputDecoration(
              hintText: 'Pilih rekening tujuan',
              prefixIcon: Container(
                margin: const EdgeInsets.only(left: 10, right: 8),
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.primaryOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _selectedDest?.destinationType == 'ewallet'
                      ? Icons.account_balance_wallet_outlined
                      : Icons.account_balance_outlined,
                  size: 18,
                  color: AppColors.primaryOrange,
                ),
              ),
            ),
            items: _destinations
                .map(
                  (d) => DropdownMenuItem(
                    value: d.id,
                    child: Text(
                      '${d.channelName} • ${d.accountNumberMasked}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: CityWalletUi.inkPrimary,
                      ),
                    ),
                  ),
                )
                .toList(),
            onChanged: locked
                ? null
                : (id) {
                    if (id == null) return;
                    setState(() {
                      _selectedDest =
                          _destinations.firstWhere((d) => d.id == id);
                    });
                  },
          ),
      ],
    );
  }

  Widget _buildAmountSection(bool locked) {
    final avail = widget.wallet.availableBalance;
    final min = widget.wallet.withdrawalMinIdr;
    final max = widget.wallet.withdrawalMaxIdr;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CityWalletUi.fieldLabel('Nominal Penarikan (IDR)'),
        const SizedBox(height: 8),
        TextField(
          controller: _amountCtrl,
          enabled: !locked,
          keyboardType: TextInputType.number,
          inputFormatters: const [RupiahDigitsInputFormatter()],
          onChanged: (_) => setState(() {}),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: CityWalletUi.inkPrimary,
          ),
          decoration: CityWalletUi.inputDecoration(
            hintText: '0',
            prefixText: 'Rp ',
            prefixStyle: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: CityWalletUi.inkMuted,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (avail >= min) _quickChip('Tarik semua', avail, locked),
            if (avail >= 50000) _quickChip('Rp 50.000', 50000, locked),
            if (avail >= 100000) _quickChip('Rp 100.000', 100000, locked),
            if (avail >= 500000) _quickChip('Rp 500.000', 500000, locked),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Minimal ${formatRupiah(min)} • Maksimal ${formatRupiah(max)}',
          style: const TextStyle(fontSize: 11.5, color: CityWalletUi.inkMuted),
        ),
      ],
    );
  }

  Widget _quickChip(String label, int value, bool locked) {
    final enabled = value > 0 && !locked;
    final selected = _parsedAmount == value && value > 0;
    return ActionChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: !enabled
              ? const Color(0xFFCBD5E1)
              : (selected ? AppColors.primaryOrange : CityWalletUi.inkSecondary),
        ),
      ),
      backgroundColor:
          selected ? AppColors.primaryOrange.withValues(alpha: 0.08) : Colors.white,
      side: BorderSide(
        color: selected ? AppColors.primaryOrange : CityWalletUi.borderColor,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onPressed: enabled ? () => _setQuickAmount(value) : null,
    );
  }

  Widget _buildSummaryCard() {
    final amount = _parsedAmount;
    final destText = _selectedDest == null
        ? 'Belum dipilih'
        : '${_selectedDest!.channelName} (${_selectedDest!.accountNumberMasked})';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: CityWalletUi.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Rincian',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: CityWalletUi.inkPrimary,
            ),
          ),
          const SizedBox(height: 10),
          _summaryRow('Nominal penarikan', formatRupiah(amount)),
          _summaryRow('Tujuan', destText),
          if (amount > 0 && _validationError != null) ...[
            const SizedBox(height: 8),
            Text(
              _validationError!,
              style: const TextStyle(
                fontSize: 11.5,
                color: CityWalletUi.errorRed,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                color: CityWalletUi.inkSecondary,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: CityWalletUi.inkPrimary,
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
        const Text(
          'Riwayat Penarikan',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: CityWalletUi.inkPrimary,
          ),
        ),
        const SizedBox(height: 10),
        if (_history.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: CityWalletUi.borderColor),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 30,
                  color: Color(0xFFCBD5E1),
                ),
                SizedBox(height: 8),
                Text(
                  'Belum ada riwayat penarikan.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: CityWalletUi.inkSecondary,
                  ),
                ),
              ],
            ),
          )
        else
          ..._history.map(
            (w) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: CityWalletUi.borderColor),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formatRupiah(w.amount),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: CityWalletUi.inkPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${w.channelCode} • ${w.accountNumberMasked}\n${w.reference}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: CityWalletUi.inkSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  WalletStatusChip(status: w.status),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
