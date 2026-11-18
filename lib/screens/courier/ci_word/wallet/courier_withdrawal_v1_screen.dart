import 'package:city_courierapp/core/config/app_colors.dart';
import 'package:city_courierapp/core/utils/currency_format.dart';
import 'package:city_courierapp/models/wallet/wallet_models.dart';
import 'package:city_courierapp/screens/courier/ci_word/wallet/courier_payout_destinations_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/wallet/courier_payout_detail_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/wallet/widgets/courier_wallet_ui.dart';
import 'package:city_courierapp/screens/profile/keamanan_akun/widgets/transaction_pin_prompt_sheet.dart';
import 'package:city_courierapp/screens/wallet/widgets/wallet_ui_components.dart';
import 'package:city_courierapp/services/wallet/courier_wallet_v1_service.dart';
import 'package:flutter/material.dart';

/// Tarik Saldo Kurir berbasis Wallet v1 Sandbox/Production (PayoutDestination + PayoutService).
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
  late final CourierWalletV1Service _service =
      widget.service ?? CourierWalletV1Service.instance;

  final TextEditingController _amountCtrl = TextEditingController();
  CourierWalletV1Summary? _summary;
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
        _service.getWallet(),
        _service.getDestinations(),
        _service.getPayouts(),
      ]);
      if (!mounted) return;
      final summary = results[0] as CourierWalletV1Summary;
      final dests = results[1] as List<PayoutDestinationV1>;
      final payouts = results[2]
          as ({
            CourierAutoPayoutStatusV1 autoPayoutStatus,
            List<PayoutTransactionV1> items,
          });
      setState(() {
        _summary = summary;
        _destinations = dests;
        _selectedDest = dests.isNotEmpty
            ? dests.firstWhere((d) => d.isDefault, orElse: () => dests.first)
            : null;
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

  Future<void> _openDestinations() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CourierPayoutDestinationsScreen(service: _service),
      ),
    );
    if (mounted) {
      await _load();
    }
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
    if (_selectedDest == null) {
      return 'Pilih atau tambahkan rekening / e-wallet tujuan.';
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

  bool get _canSubmit =>
      !_loading && !_submitting && _summary != null && _validationError == null;

  void _setQuickAmount(int value) {
    setState(() {
      _amountCtrl.text = CourierRupiahInputFormatter.formatDigits(value);
    });
  }

  Future<void> _submit() async {
    final summary = _summary;
    final dest = _selectedDest;
    final amount = _parsedAmount;

    if (summary == null) return;
    if (dest == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tambahkan rekening bank atau e-wallet tujuan terlebih dahulu.'),
        ),
      );
      return;
    }
    if (amount < summary.minPayoutIdr ||
        amount > summary.maxPayoutIdr ||
        amount > summary.availableBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Nominal harus antara ${formatRupiah(summary.minPayoutIdr)} dan '
            '${formatRupiah(summary.availableBalance < summary.maxPayoutIdr ? summary.availableBalance : summary.maxPayoutIdr)}.',
          ),
        ),
      );
      return;
    }

    String? pin;
    if (summary.hasTransactionPin) {
      pin = await TransactionPinPromptSheet.show(
        context,
        subtitle: 'Masukkan 6 digit PIN transaksi untuk menarik saldo.',
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
          content: Text('Permintaan penarikan saldo berhasil diajukan.'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
      await _load();
    } on WalletApiException catch (e) {
      if (e.errorCode == 'TRANSACTION_PIN_REQUIRED' && mounted) {
        setState(() => _submitting = false);
        final prompted = await TransactionPinPromptSheet.show(
          context,
          subtitle: 'Masukkan 6 digit PIN transaksi untuk mengonfirmasi penarikan.',
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
              content: Text('Permintaan penarikan saldo berhasil diajukan.'),
              backgroundColor: Color(0xFF16A34A),
            ),
          );
          await _load();
          return;
        } catch (err) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err.toString()), backgroundColor: CourierWalletUi.errorRed),
          );
          return;
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: CourierWalletUi.errorRed),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: CourierWalletUi.errorRed),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    final blocked = summary != null &&
        (summary.isFrozen || !summary.payoutProviderEnabled);

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            CourierWalletUi.buildHeader(context, title: 'Tarik Saldo'),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.primaryOrange),
                    )
                  : _error != null
                      ? WalletErrorState(message: _error!, onRetry: _load)
                      : RefreshIndicator(
                          color: AppColors.primaryOrange,
                          onRefresh: _load,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                            children: [
                              if (summary != null && summary.isFrozen)
                                _bannerCard(
                                  icon: Icons.ac_unit_rounded,
                                  title: 'Dompet Dibekukan',
                                  message: summary.freezeReason ??
                                      'Penarikan sementara ditahan. Hubungi Admin City Courier.',
                                ),
                              if (summary != null && !summary.payoutProviderEnabled)
                                _bannerCard(
                                  icon: Icons.pause_circle_outline_rounded,
                                  title: 'Gateway Pencairan Dinonaktifkan',
                                  message:
                                      'Layanan pencairan (${summary.activePayoutProvider.toUpperCase()}) sedang dinonaktifkan oleh Admin.',
                                ),
                              _buildBalanceCard(summary),
                              const SizedBox(height: 20),
                              _buildDestinationSection(blocked),
                              const SizedBox(height: 20),
                              _buildAmountSection(summary, blocked),
                              const SizedBox(height: 20),
                              _buildSummaryCard(summary),
                              const SizedBox(height: 24),
                              _buildHistorySection(),
                            ],
                          ),
                        ),
            ),
            if (!_loading && _error == null)
              CourierWalletUi.stickyBottomBar(
                context,
                securityNote:
                    'Saldo dipotong aman saat pengajuan dibuat; status pencairan diperbarui otomatis.',
                child: SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: (blocked || _submitting) ? null : _submit,
                    style: CourierWalletUi.primaryButtonStyle(
                      enabled: _canSubmit || (!blocked && !_submitting),
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
                            blocked ? 'Penarikan Tidak Tersedia' : 'Ajukan Penarikan',
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard(CourierWalletV1Summary? summary) {
    final available = summary?.availableBalance ?? 0;
    final pending = summary?.pendingBalance ?? 0;
    final reserved = summary?.reservedBalance ?? 0;

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
              if (summary != null)
                EnvironmentModeBadge(
                  mode: summary.mode,
                  isSimulated: summary.isSandboxOrDemo,
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            formatRupiah(available),
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.4,
            ),
          ),
          if (pending > 0 || reserved > 0) ...[
            const SizedBox(height: 8),
            Container(height: 1, color: Colors.white24),
            if (pending > 0) ...[
              const SizedBox(height: 8),
              Text(
                'Dalam proses settlement: ${formatRupiah(pending)}',
                style: const TextStyle(fontSize: 11.5, color: Colors.white70),
              ),
            ],
            if (reserved > 0) ...[
              const SizedBox(height: 4),
              Text(
                'Dalam proses pencairan: ${formatRupiah(reserved)}',
                style: const TextStyle(fontSize: 11.5, color: Colors.white70),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildDestinationSection(bool blocked) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CourierWalletUi.fieldLabel(
          'Rekening / E-Wallet Tujuan',
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
              border: Border.all(color: CourierWalletUi.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Belum ada rekening bank atau e-wallet tersimpan.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: CourierWalletUi.inkSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _openDestinations,
                  style: CourierWalletUi.secondaryButtonStyle(
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
            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: CourierWalletUi.inkSecondary),
            decoration: CourierWalletUi.inputDecoration(
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
                        color: CourierWalletUi.inkPrimary,
                      ),
                    ),
                  ),
                )
                .toList(),
            onChanged: blocked
                ? null
                : (id) {
                    if (id == null) return;
                    setState(() {
                      _selectedDest = _destinations.firstWhere((d) => d.id == id);
                    });
                  },
          ),
      ],
    );
  }

  Widget _buildAmountSection(CourierWalletV1Summary? summary, bool blocked) {
    final available = summary?.availableBalance ?? 0;
    final min = summary?.minPayoutIdr ?? 20000;
    final max = summary?.maxPayoutIdr ?? 5000000;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CourierWalletUi.fieldLabel('Nominal Penarikan'),
        const SizedBox(height: 8),
        TextField(
          controller: _amountCtrl,
          enabled: !blocked,
          keyboardType: TextInputType.number,
          inputFormatters: const [CourierRupiahInputFormatter()],
          onChanged: (_) => setState(() {}),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: CourierWalletUi.inkPrimary,
          ),
          decoration: CourierWalletUi.inputDecoration(
            hintText: '0',
            prefixText: 'Rp ',
            prefixStyle: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: CourierWalletUi.inkMuted,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (available >= min) _buildQuickChip('Tarik semua', available, blocked),
            if (available >= 50000) _buildQuickChip('Rp 50.000', 50000, blocked),
            if (available >= 100000) _buildQuickChip('Rp 100.000', 100000, blocked),
            if (available >= 500000) _buildQuickChip('Rp 500.000', 500000, blocked),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Minimal ${formatRupiah(min)} • Maksimal ${formatRupiah(max)}',
          style: const TextStyle(fontSize: 11.5, color: CourierWalletUi.inkMuted),
        ),
      ],
    );
  }

  Widget _buildQuickChip(String label, int value, bool blocked) {
    final enabled = value > 0 && !blocked;
    final selected = _parsedAmount == value && value > 0;

    return ActionChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: !enabled
              ? const Color(0xFFCBD5E1)
              : (selected ? AppColors.primaryOrange : CourierWalletUi.inkSecondary),
        ),
      ),
      backgroundColor:
          selected ? AppColors.primaryOrange.withValues(alpha: 0.08) : Colors.white,
      side: BorderSide(
        color: selected ? AppColors.primaryOrange : CourierWalletUi.borderColor,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onPressed: enabled ? () => _setQuickAmount(value) : null,
    );
  }

  Widget _buildSummaryCard(CourierWalletV1Summary? summary) {
    final amount = _parsedAmount;
    final fee = summary?.feeIdr ?? 0;
    final net = amount > fee ? amount - fee : 0;
    final destText = _selectedDest == null
        ? 'Belum dipilih'
        : '${_selectedDest!.channelName} (${_selectedDest!.accountNumberMasked})';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: CourierWalletUi.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Rincian',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: CourierWalletUi.inkPrimary,
            ),
          ),
          const SizedBox(height: 10),
          _summaryRow('Nominal penarikan', formatRupiah(amount)),
          _summaryRow('Biaya admin', fee == 0 ? 'Gratis' : formatRupiah(fee)),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1, color: CourierWalletUi.dividerColor),
          ),
          _summaryRow('Total diterima', formatRupiah(net), bold: true),
          _summaryRow('Tujuan', destText),
          if (amount > 0 && _validationError != null) ...[
            const SizedBox(height: 8),
            Text(
              _validationError!,
              style: const TextStyle(fontSize: 11.5, color: CourierWalletUi.errorRed),
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12.5, color: CourierWalletUi.inkSecondary),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                color: CourierWalletUi.inkPrimary,
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
            color: CourierWalletUi.inkPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: CourierWalletUi.borderColor),
          ),
          child: _history.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                  child: Column(
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 30, color: Color(0xFFCBD5E1)),
                      SizedBox(height: 8),
                      Text(
                        'Belum ada riwayat penarikan saldo',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: CourierWalletUi.inkSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    for (var i = 0; i < _history.length; i++) ...[
                      if (i > 0)
                        const Divider(height: 1, indent: 16, color: CourierWalletUi.dividerColor),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CourierPayoutDetailScreen(
                              payoutId: _history[i].id,
                              service: _service,
                            ),
                          ),
                        ),
                        title: Text(
                          formatRupiah(_history[i].amount),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: CourierWalletUi.inkPrimary,
                          ),
                        ),
                        subtitle: Text(
                          '${_history[i].channelCode} • ${_history[i].accountNumberMasked}\n${_history[i].reference}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: CourierWalletUi.inkSecondary,
                          ),
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            WalletStatusChip(status: _history[i].status),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: CourierWalletUi.inkMuted,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _bannerCard({
    required IconData icon,
    required String title,
    required String message,
  }) {
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
          Icon(icon, color: const Color(0xFFB45309)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF78350F)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
