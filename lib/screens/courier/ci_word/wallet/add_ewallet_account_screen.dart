import 'package:city_courierapp/core/config/app_colors.dart';
import 'package:city_courierapp/screens/courier/ci_word/wallet/widgets/courier_wallet_ui.dart';
import 'package:city_courierapp/screens/wallet/widgets/wallet_ui_components.dart';
import 'package:city_courierapp/services/wallet/courier_wallet_v1_service.dart';
import 'package:city_courierapp/widgets/payment/payment_brand_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AddEwalletAccountScreen extends StatefulWidget {
  final CourierWalletV1Service? service;
  final List<(String, String)>? supportedChannels;

  const AddEwalletAccountScreen({
    super.key,
    this.service,
    this.supportedChannels,
  });

  @override
  State<AddEwalletAccountScreen> createState() =>
      _AddEwalletAccountScreenState();
}

class _AddEwalletAccountScreenState extends State<AddEwalletAccountScreen> {
  late final CourierWalletV1Service _service =
      widget.service ?? CourierWalletV1Service.instance;
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _holderCtrl = TextEditingController();
  late final DestinationNameInquiryController _inquiry =
      DestinationNameInquiryController(inquireFn: _service.inquireDestination);
  late List<(String, String)> _ewallets =
      widget.supportedChannels ?? _defaultEwallets;
  late String _channelCode =
      _ewallets.isNotEmpty ? _ewallets.first.$1 : 'ID_DANA';
  bool _setAsDefault = true;
  bool _saving = false;

  static const _defaultEwallets = [
    ('ID_GOPAY', 'GoPay'),
    ('ID_DANA', 'DANA'),
    ('ID_OVO', 'OVO'),
    ('ID_SHOPEEPAY', 'ShopeePay'),
    ('ID_LINKAJA', 'LinkAja'),
  ];

  @override
  void initState() {
    super.initState();
    _inquiry.addListener(_onInquiryUpdated);
    if (widget.supportedChannels == null) {
      _loadSupportedChannels();
    }
  }

  Future<void> _loadSupportedChannels() async {
    try {
      final bundle = await _service.getDestinationsBundle();
      if (!mounted || !bundle.hasServerChannels) return;
      setState(() {
        _ewallets = bundle.ewalletChannels;
        if (_ewallets.isNotEmpty &&
            !_ewallets.any((e) => e.$1 == _channelCode)) {
          _channelCode = _ewallets.first.$1;
        }
      });
    } catch (_) {
      // Tetap gunakan katalog default Xendit saat fetch kanal belum terjangkau.
    }
  }

  void _onInquiryUpdated() {
    if (mounted) setState(() {});
  }

  void _scheduleInquiry() {
    _inquiry.schedule(
      destinationType: 'ewallet',
      channelCode: _channelCode,
      rawNumber: _phoneCtrl.text,
      holderController: _holderCtrl,
    );
  }

  @override
  void dispose() {
    _inquiry.removeListener(_onInquiryUpdated);
    _inquiry.dispose();
    _phoneCtrl.dispose();
    _holderCtrl.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      !_saving &&
      _phoneCtrl.text.trim().length >= 9 &&
      _holderCtrl.text.trim().isNotEmpty;

  Future<void> _submit() async {
    if (_phoneCtrl.text.trim().length < 9 || _holderCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Masukkan nomor e-wallet & nama akun dengan benar.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await _service.addDestination(
        destinationType: 'ewallet',
        channelCode: _channelCode,
        accountNumber: _phoneCtrl.text.trim(),
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
              title: 'Tambah Akun E-Wallet',
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  CourierWalletUi.fieldLabel('Pilih E-Wallet'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _ewallets.map((item) {
                      final selected = _channelCode == item.$1;
                      return ChoiceChip(
                        avatar: PaymentBrandLogo(
                          method: item.$2,
                          size: 22,
                          width: 30,
                          borderRadius: 5,
                        ),
                        label: Text(
                          item.$2,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: selected
                                ? AppColors.primaryOrange
                                : CourierWalletUi.inkPrimary,
                          ),
                        ),
                        selected: selected,
                        showCheckmark: false,
                        selectedColor:
                            AppColors.primaryOrange.withValues(alpha: 0.08),
                        backgroundColor: Colors.white,
                        side: BorderSide(
                          color: selected
                              ? AppColors.primaryOrange
                              : CourierWalletUi.borderColor,
                          width: selected ? 1.4 : 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        onSelected: (_) {
                          setState(() => _channelCode = item.$1);
                          _scheduleInquiry();
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),
                  CourierWalletUi.fieldLabel('Nomor HP Terdaftar'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
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
                      hintText: '08xxxxxxxxxx',
                      prefixIcon: Container(
                        margin: const EdgeInsets.only(left: 10, right: 8),
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: CourierWalletUi.borderColor),
                        ),
                        child: const Icon(
                          Icons.phone_android_outlined,
                          size: 18,
                          color: CourierWalletUi.inkSecondary,
                        ),
                      ),
                    ),
                  ),
                  DestinationInquiryStatusBanner(
                    controller: _inquiry,
                    onUseDetectedName: () =>
                        _inquiry.restoreAutoFill(_holderCtrl),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Contoh: 081234567890. Nama akun e-wallet terisi otomatis bila tersedia.',
                    style: TextStyle(fontSize: 11.5, color: CourierWalletUi.inkMuted),
                  ),
                  const SizedBox(height: 18),
                  CourierWalletUi.fieldLabel(
                    'Nama Pemilik Akun E-Wallet',
                    trailing: WalletStatusChip(
                      status: _inquiry.hasAutoFilled
                          ? 'auto_verified'
                          : (_inquiry.result?.verificationStatus ??
                              'unverified'),
                    ),
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
                      hintText: 'Nama pemilik sesuai akun e-wallet',
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
                                'Jadikan E-Wallet Utama',
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
                  'Akun e-wallet tersimpan aman untuk pencairan saldo kurir.',
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
                        'Simpan E-Wallet',
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
