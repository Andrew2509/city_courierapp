import 'package:city_courierapp/core/config/app_colors.dart';
import 'package:city_courierapp/screens/courier/ci_word/wallet/widgets/courier_wallet_ui.dart';
import 'package:city_courierapp/screens/wallet/widgets/wallet_ui_components.dart';
import 'package:city_courierapp/services/wallet/courier_wallet_v1_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AddBankAccountScreen extends StatefulWidget {
  final CourierWalletV1Service? service;

  const AddBankAccountScreen({super.key, this.service});

  @override
  State<AddBankAccountScreen> createState() => _AddBankAccountScreenState();
}

class _AddBankAccountScreenState extends State<AddBankAccountScreen> {
  late final CourierWalletV1Service _service =
      widget.service ?? CourierWalletV1Service.instance;
  final TextEditingController _numberCtrl = TextEditingController();
  final TextEditingController _holderCtrl = TextEditingController();
  late final DestinationNameInquiryController _inquiry =
      DestinationNameInquiryController(inquireFn: _service.inquireDestination);
  String _channelCode = 'ID_BCA';
  bool _setAsDefault = true;
  bool _saving = false;

  static const _banks = [
    ('ID_BCA', 'Bank BCA'),
    ('ID_BRI', 'Bank BRI'),
    ('ID_BNI', 'Bank BNI'),
    ('ID_MANDIRI', 'Bank Mandiri'),
    ('ID_PERMATA', 'Bank Permata'),
    ('ID_CIMB', 'Bank CIMB Niaga'),
    ('ID_BSI', 'Bank Syariah Indonesia (BSI)'),
  ];

  @override
  void initState() {
    super.initState();
    _inquiry.addListener(_onInquiryUpdated);
  }

  void _onInquiryUpdated() {
    if (mounted) setState(() {});
  }

  void _scheduleInquiry() {
    _inquiry.schedule(
      destinationType: 'bank',
      channelCode: _channelCode,
      rawNumber: _numberCtrl.text,
      holderController: _holderCtrl,
    );
  }

  @override
  void dispose() {
    _inquiry.removeListener(_onInquiryUpdated);
    _inquiry.dispose();
    _numberCtrl.dispose();
    _holderCtrl.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      !_saving &&
      _numberCtrl.text.trim().length >= 6 &&
      _holderCtrl.text.trim().isNotEmpty;

  Future<void> _submit() async {
    if (_numberCtrl.text.trim().length < 6 || _holderCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Masukkan nomor rekening dan nama pemilik dengan benar.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await _service.addDestination(
        destinationType: 'bank',
        channelCode: _channelCode,
        accountNumber: _numberCtrl.text.trim(),
        accountHolderName: _holderCtrl.text.trim(),
        isDefault: _setAsDefault,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: CourierWalletUi.errorRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            CourierWalletUi.buildHeader(
              context,
              title: 'Tambah Rekening Bank',
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  CourierWalletUi.fieldLabel('Pilih Bank'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _channelCode,
                    isExpanded: true,
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: CourierWalletUi.inkSecondary,
                    ),
                    decoration: CourierWalletUi.inputDecoration(
                      hintText: 'Pilih Bank',
                      prefixIcon: Container(
                        margin: const EdgeInsets.only(left: 10, right: 8),
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: AppColors.primaryOrange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.account_balance_outlined,
                          size: 18,
                          color: AppColors.primaryOrange,
                        ),
                      ),
                    ),
                    items: _banks
                        .map(
                          (b) => DropdownMenuItem(
                            value: b.$1,
                            child: Text(
                              b.$2,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: CourierWalletUi.inkPrimary,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _channelCode = v);
                        _scheduleInquiry();
                      }
                    },
                  ),
                  const SizedBox(height: 18),
                  CourierWalletUi.fieldLabel('Nomor Rekening Bank'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _numberCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) {
                      setState(() {});
                      _scheduleInquiry();
                    },
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: CourierWalletUi.inkPrimary,
                    ),
                    decoration: CourierWalletUi.inputDecoration(
                      hintText: 'Contoh: 1234567890',
                    ),
                  ),
                  DestinationInquiryStatusBanner(
                    controller: _inquiry,
                    onUseDetectedName: () =>
                        _inquiry.restoreAutoFill(_holderCtrl),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Pastikan nomor rekening aktif; nama pemilik diisi otomatis bila tersedia.',
                    style: TextStyle(fontSize: 11.5, color: CourierWalletUi.inkMuted),
                  ),
                  const SizedBox(height: 18),
                  CourierWalletUi.fieldLabel(
                    'Nama Pemilik Rekening',
                    trailing: _inquiry.hasAutoFilled
                        ? const Text(
                            'Terisi otomatis',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF15803D),
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _holderCtrl,
                    textCapitalization: TextCapitalization.characters,
                    onChanged: (val) {
                      _inquiry.onManualNameEdited(val);
                      setState(() {});
                    },
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: CourierWalletUi.inkPrimary,
                    ),
                    decoration: CourierWalletUi.inputDecoration(
                      hintText: 'Nama pemilik sesuai buku tabungan',
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: CourierWalletUi.borderColor),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Jadikan Rekening Utama',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: CourierWalletUi.inkPrimary,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Dipilih otomatis saat tarik saldo',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: CourierWalletUi.inkSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _setAsDefault,
                          activeTrackColor:
                              AppColors.primaryOrange.withValues(alpha: 0.4),
                          activeThumbColor: AppColors.primaryOrange,
                          onChanged: (val) => setState(() => _setAsDefault = val),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            CourierWalletUi.stickyBottomBar(
              context,
              securityIcon: Icons.verified_user_outlined,
              securityNote:
                  'Data rekening tersimpan aman untuk penarikan saldo kurir.',
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                style: CourierWalletUi.primaryButtonStyle(
                  enabled: _canSubmit || !_saving,
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Simpan Rekening Bank',
                        style: TextStyle(
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
}
