import 'package:city_courierapp/core/config/app_typography.dart';
import 'package:city_courierapp/core/utils/currency_format.dart';
import 'package:city_courierapp/models/wallet/wallet_models.dart';
import 'package:city_courierapp/screens/wallet/widgets/wallet_ui_components.dart';
import 'package:city_courierapp/services/wallet/customer_wallet_service.dart';
import 'package:flutter/material.dart';

class CustomerRefundScreen extends StatefulWidget {
  final CustomerWalletService? service;

  const CustomerRefundScreen({super.key, this.service});

  @override
  State<CustomerRefundScreen> createState() => _CustomerRefundScreenState();
}

class _CustomerRefundScreenState extends State<CustomerRefundScreen> {
  late final CustomerWalletService _service =
      widget.service ?? CustomerWalletService.instance;
  final TextEditingController _reasonCtrl = TextEditingController();
  List<RefundTransactionV1> _refunds = [];
  List<EligibleRefundShipment> _eligible = [];
  EligibleRefundShipment? _selected;
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
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _service.getRefunds();
      if (!mounted) return;
      setState(() {
        _refunds = res.items;
        _eligible = res.eligibleShipments;
        _selected = _eligible.isNotEmpty ? _eligible.first : null;
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

  Future<void> _submit() async {
    if (_selected == null) return;
    final reason = _reasonCtrl.text.trim();
    if (reason.length < 5) {
      CityWalletUi.showSnackBar(
        context,
        'Masukkan alasan refund minimal 5 karakter.',
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await _service.requestRefund(shipmentId: _selected!.id, reason: reason);
      if (!mounted) return;
      _reasonCtrl.clear();
      CityWalletUi.showSnackBar(
        context,
        'Pengajuan refund berhasil dikirim.',
        backgroundColor: CityWalletUi.successGreen,
      );
      _load();
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
    return Scaffold(
      backgroundColor: CityWalletUi.scaffoldBg(context),
      appBar: CityWalletUi.buildAppBar(context, title: 'Pengajuan Refund'),
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
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: CityWalletUi.noticeDecoration(context),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.info_outline_rounded,
                                    size: 20,
                                    color: CityWalletUi.primaryColor,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Refund tersedia untuk pesanan lunas yang belum selesai dikirim. Dana disetujui masuk ke City Wallet.',
                                      style: AppTypography.bodySmall.copyWith(
                                        fontSize: 12.5,
                                        color: CityWalletUi.ink(context),
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            if (_eligible.isEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 28,
                                  horizontal: 16,
                                ),
                                decoration: CityWalletUi.cardDecoration(
                                  context,
                                  radius: 16,
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.assignment_turned_in_outlined,
                                      size: 36,
                                      color: CityWalletUi.mutedInk(context),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Tidak ada pesanan lunas yang memenuhi syarat refund saat ini.',
                                      textAlign: TextAlign.center,
                                      style: CityWalletUi.bodyStyle(context)
                                          .copyWith(fontSize: 12.5),
                                    ),
                                  ],
                                ),
                              )
                            else ...[
                              CityWalletUi.fieldLabel(
                                'Pilih Pesanan',
                                context: context,
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<int>(
                                initialValue: _selected?.id,
                                isExpanded: true,
                                dropdownColor: CityWalletUi.cardBg(context),
                                icon: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: CityWalletUi.secondaryInk(context),
                                ),
                                decoration: CityWalletUi.inputDecoration(
                                  context: context,
                                  hintText: 'Pilih pesanan',
                                  prefixIcon: Container(
                                    margin: const EdgeInsets.only(
                                      left: 10,
                                      right: 8,
                                    ),
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: CityWalletUi.primaryColor
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.local_shipping_outlined,
                                      size: 18,
                                      color: CityWalletUi.primaryColor,
                                    ),
                                  ),
                                ),
                                items: _eligible
                                    .map(
                                      (s) => DropdownMenuItem(
                                        value: s.id,
                                        child: Text(
                                          '${s.shipmentNumber} (${formatRupiah(s.totalCost)})',
                                          overflow: TextOverflow.ellipsis,
                                          style: CityWalletUi.cardTitleStyle(
                                            context,
                                          ).copyWith(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (id) {
                                  if (id != null) {
                                    setState(() => _selected =
                                        _eligible.firstWhere(
                                            (e) => e.id == id));
                                  }
                                },
                              ),
                              const SizedBox(height: 18),
                              CityWalletUi.fieldLabel(
                                'Alasan Pengajuan Refund',
                                context: context,
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _reasonCtrl,
                                maxLines: 3,
                                onChanged: (_) => setState(() {}),
                                style: AppTypography.bodySmall.copyWith(
                                  fontSize: 13.5,
                                  color: CityWalletUi.ink(context),
                                ),
                                decoration: CityWalletUi.inputDecoration(
                                  context: context,
                                  hintText:
                                      'Tuliskan alasan pembatalan atau kendala pengiriman',
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
                            Text(
                              'Status Refund',
                              style: CityWalletUi.sectionTitleStyle(context),
                            ),
                            const SizedBox(height: 10),
                            if (_refunds.isEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 28,
                                  horizontal: 16,
                                ),
                                decoration: CityWalletUi.cardDecoration(
                                  context,
                                  radius: 16,
                                ),
                                child: Center(
                                  child: Text(
                                    'Belum ada pengajuan refund.',
                                    style: CityWalletUi.bodyStyle(context)
                                        .copyWith(fontSize: 12.5),
                                  ),
                                ),
                              )
                            else
                              ..._refunds.map(
                                (r) => Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(14),
                                  decoration: CityWalletUi.cardDecoration(
                                    context,
                                    radius: 14,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${r.reference} • ${formatRupiah(r.amount)}',
                                              style: CityWalletUi.cardTitleStyle(
                                                context,
                                              ).copyWith(fontSize: 13.5),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              r.reviewNotes ?? r.reason,
                                              style: CityWalletUi.bodyStyle(
                                                context,
                                              ).copyWith(fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      WalletStatusChip(status: r.status),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
          ),
          if (!_loading && _error == null && _eligible.isNotEmpty)
            CityWalletUi.stickyBottomBar(
              context,
              securityNote:
                  'Tim Admin meninjau pengajuan refund sebelum dana dikreditkan ke saldo Anda.',
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: CityWalletUi.primaryButtonStyle(
                  enabled: !_submitting,
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
                    : const Text('Kirim Pengajuan Refund'),
              ),
            ),
        ],
      ),
    );
  }
}
