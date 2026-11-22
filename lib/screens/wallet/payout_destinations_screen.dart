import 'package:city_courierapp/core/config/app_typography.dart';
import 'package:city_courierapp/models/wallet/wallet_models.dart';
import 'package:city_courierapp/screens/wallet/widgets/wallet_ui_components.dart';
import 'package:city_courierapp/services/wallet/customer_wallet_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PayoutDestinationsScreen extends StatefulWidget {
  final CustomerWalletService? service;

  const PayoutDestinationsScreen({super.key, this.service});

  @override
  State<PayoutDestinationsScreen> createState() =>
      _PayoutDestinationsScreenState();
}

class _PayoutDestinationsScreenState extends State<PayoutDestinationsScreen> {
  late final CustomerWalletService _service =
      widget.service ?? CustomerWalletService.instance;
  List<PayoutDestinationV1> _items = [];
  bool _loading = true;
  String? _error;

  List<(String, String)> _bankChannels = _defaultBankChannels;
  List<(String, String)> _ewalletChannels = _defaultEwalletChannels;

  static const _defaultBankChannels = [
    ('ID_BCA', 'Bank BCA'),
    ('ID_BRI', 'Bank BRI'),
    ('ID_BNI', 'Bank BNI'),
    ('ID_MANDIRI', 'Bank Mandiri'),
    ('ID_PERMATA', 'Bank Permata'),
    ('ID_CIMB', 'Bank CIMB Niaga'),
    ('ID_BSI', 'Bank Syariah Indonesia (BSI)'),
  ];

  static const _defaultEwalletChannels = [
    ('ID_DANA', 'DANA'),
    ('ID_OVO', 'OVO'),
    ('ID_GOPAY', 'GoPay'),
    ('ID_SHOPEEPAY', 'ShopeePay'),
    ('ID_LINKAJA', 'LinkAja'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bundle = await _service.getDestinationsBundle();
      if (!mounted) return;
      setState(() {
        _items = bundle.items;
        if (bundle.hasServerChannels) {
          _bankChannels = bundle.bankChannels;
          _ewalletChannels = bundle.ewalletChannels;
        }
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

  Future<void> _openAddSheet({String initialType = 'bank'}) async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: CityWalletUi.cardBg(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AddCustomerDestinationSheet(
        service: _service,
        initialType: initialType,
        bankChannels: _bankChannels,
        ewalletChannels: _ewalletChannels,
      ),
    );
    if (added == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CityWalletUi.scaffoldBg(context),
      appBar: CityWalletUi.buildAppBar(context, title: 'Rekening & E-Wallet'),
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
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: CityWalletUi.noticeDecoration(context),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.verified_user_outlined,
                                    size: 20,
                                    color: CityWalletUi.primaryColor,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Pilih akun utama atau tambahkan rekening bank / e-wallet untuk penarikan dana.',
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
                            const SizedBox(height: 16),
                            if (_items.isEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 36,
                                  horizontal: 20,
                                ),
                                decoration: CityWalletUi.cardDecoration(
                                  context,
                                  radius: 16,
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.account_balance_wallet_outlined,
                                      size: 40,
                                      color: CityWalletUi.mutedInk(context),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'Belum ada rekening bank atau e-wallet terdaftar',
                                      textAlign: TextAlign.center,
                                      style:
                                          CityWalletUi.cardTitleStyle(context),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Tekan tombol di bawah untuk menambahkan rekening tujuan baru.',
                                      textAlign: TextAlign.center,
                                      style: CityWalletUi.bodyStyle(context)
                                          .copyWith(fontSize: 12),
                                    ),
                                  ],
                                ),
                              )
                            else
                              ..._items.map(_buildDestinationCard),
                          ],
                        ),
                      ),
          ),
          if (!_loading && _error == null)
            CityWalletUi.stickyBottomBar(
              context,
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openAddSheet(initialType: 'bank'),
                      style: CityWalletUi.secondaryButtonStyle(
                        borderTint:
                            CityWalletUi.primaryColor.withValues(alpha: 0.45),
                        fgColor: CityWalletUi.primaryColor,
                        context: context,
                      ),
                      icon: const Icon(
                        Icons.account_balance_outlined,
                        size: 18,
                      ),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('+ Rekening Bank', maxLines: 1),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _openAddSheet(initialType: 'ewallet'),
                      style: CityWalletUi.primaryButtonStyle(context: context),
                      icon: const Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 18,
                      ),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('+ E-Wallet', maxLines: 1),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDestinationCard(PayoutDestinationV1 d) {
    final isBank = d.destinationType == 'bank';
    final dark = CityWalletUi.isDark(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: CityWalletUi.cardDecoration(
        context,
        isHighlighted: d.isDefault,
        radius: 14,
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isBank
                  ? CityWalletUi.primaryColor.withValues(alpha: 0.1)
                  : (dark
                      ? const Color(0xFF064E3B)
                      : const Color(0xFFECFDF5)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isBank
                  ? Icons.account_balance_outlined
                  : Icons.account_balance_wallet_outlined,
              size: 20,
              color: isBank
                  ? CityWalletUi.primaryColor
                  : const Color(0xFF15803D),
            ),
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
                        d.channelName,
                        overflow: TextOverflow.ellipsis,
                        style: CityWalletUi.cardTitleStyle(context).copyWith(
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                    if (d.isDefault) ...[
                      const SizedBox(width: 6),
                      const WalletStatusChip(status: 'default'),
                    ],
                    const SizedBox(width: 6),
                    WalletStatusChip(status: d.normalizedVerificationStatus),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${d.accountNumberMasked} • ${d.accountHolderName}',
                  overflow: TextOverflow.ellipsis,
                  style: CityWalletUi.bodyStyle(context).copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (d.isDefault)
            const Icon(
              Icons.check_circle_rounded,
              color: CityWalletUi.successGreen,
              size: 22,
            )
          else
            OutlinedButton(
              onPressed: () async {
                await _service.setDefaultDestination(d.id);
                _load();
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: CityWalletUi.primaryColor,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                side: BorderSide(
                  color: CityWalletUi.primaryColor.withValues(alpha: 0.45),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: AppTypography.caption.copyWith(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              child: const Text('Jadikan Default'),
            ),
        ],
      ),
    );
  }
}

class _AddCustomerDestinationSheet extends StatefulWidget {
  final CustomerWalletService service;
  final String initialType;
  final List<(String, String)> bankChannels;
  final List<(String, String)> ewalletChannels;

  const _AddCustomerDestinationSheet({
    required this.service,
    required this.initialType,
    required this.bankChannels,
    required this.ewalletChannels,
  });

  @override
  State<_AddCustomerDestinationSheet> createState() =>
      _AddCustomerDestinationSheetState();
}

class _AddCustomerDestinationSheetState
    extends State<_AddCustomerDestinationSheet> {
  final TextEditingController _numCtrl = TextEditingController();
  final TextEditingController _nameCtrl = TextEditingController();
  late final DestinationNameInquiryController _inquiry =
      DestinationNameInquiryController(
    inquireFn: widget.service.inquireDestination,
  );

  late String _destType = widget.initialType;
  late String _channelCode = (widget.initialType == 'bank'
          ? widget.bankChannels
          : widget.ewalletChannels)
      .first
      .$1;
  bool _saving = false;
  String? _sheetError;

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
      destinationType: _destType,
      channelCode: _channelCode,
      rawNumber: _numCtrl.text,
      holderController: _nameCtrl,
    );
  }

  @override
  void dispose() {
    _inquiry.removeListener(_onInquiryUpdated);
    _inquiry.dispose();
    _numCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_numCtrl.text.trim().length < 6 || _nameCtrl.text.trim().isEmpty) {
      setState(() {
        _sheetError = 'Isi nomor rekening & nama pemilik dengan valid.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _sheetError = null;
    });

    try {
      await widget.service.addDestination(
        destinationType: _destType,
        channelCode: _channelCode,
        accountNumber: _numCtrl.text.trim(),
        accountHolderName: _nameCtrl.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _sheetError = e.toString();
        });
      }
    }
  }

  Widget _typePill({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected
          ? CityWalletUi.primaryColor.withValues(alpha: 0.08)
          : CityWalletUi.cardBg(context),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
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
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected
                    ? CityWalletUi.primaryColor
                    : CityWalletUi.secondaryInk(context),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.titleSmall.copyWith(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? CityWalletUi.primaryColor
                      : CityWalletUi.ink(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final channels =
        _destType == 'bank' ? widget.bankChannels : widget.ewalletChannels;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
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
            const SizedBox(height: 16),
            Text(
              'Tambah Rekening / E-Wallet',
              style: AppTypography.titleMedium.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: CityWalletUi.ink(context),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _typePill(
                    label: 'Rekening Bank',
                    icon: Icons.account_balance_outlined,
                    selected: _destType == 'bank',
                    onTap: () {
                      setState(() {
                        _destType = 'bank';
                        _channelCode = widget.bankChannels.first.$1;
                      });
                      _scheduleInquiry();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _typePill(
                    label: 'E-Wallet',
                    icon: Icons.account_balance_wallet_outlined,
                    selected: _destType == 'ewallet',
                    onTap: () {
                      setState(() {
                        _destType = 'ewallet';
                        _channelCode = widget.ewalletChannels.first.$1;
                      });
                      _scheduleInquiry();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            CityWalletUi.fieldLabel(
              _destType == 'bank' ? 'Pilih Bank' : 'Pilih E-Wallet',
              context: context,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              key: ValueKey(_destType),
              initialValue: _channelCode,
              isExpanded: true,
              dropdownColor: CityWalletUi.cardBg(context),
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: CityWalletUi.secondaryInk(context),
              ),
              decoration: CityWalletUi.inputDecoration(
                context: context,
                hintText: 'Pilih bank atau e-wallet',
              ),
              items: channels
                  .map(
                    (c) => DropdownMenuItem(
                      value: c.$1,
                      child: Text(
                        c.$2,
                        style: CityWalletUi.cardTitleStyle(context).copyWith(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
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
            const SizedBox(height: 14),
            CityWalletUi.fieldLabel(
              _destType == 'bank' ? 'Nomor Rekening' : 'Nomor HP E-Wallet',
              context: context,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _numCtrl,
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
                hintText: _destType == 'bank'
                    ? 'Contoh: 1234567890'
                    : '08xxxxxxxxxx',
              ),
            ),
            DestinationInquiryStatusBanner(
              controller: _inquiry,
              onUseDetectedName: () => _inquiry.restoreAutoFill(_nameCtrl),
            ),
            const SizedBox(height: 14),
            CityWalletUi.fieldLabel(
              'Nama Pemilik Rekening',
              context: context,
              trailing: WalletStatusChip(
                status: _inquiry.hasAutoFilled
                    ? 'auto_verified'
                    : (_inquiry.result?.verificationStatus ?? 'unverified'),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameCtrl,
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
            if (_sheetError != null) ...[
              const SizedBox(height: 10),
              Text(
                _sheetError!,
                style: AppTypography.caption.copyWith(
                  fontSize: 12,
                  color: CityWalletUi.errorRed,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: CityWalletUi.primaryButtonStyle(
                enabled: !_saving,
                context: context,
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
                  : const Text('Simpan Rekening Tujuan'),
            ),
          ],
        ),
      ),
    );
  }
}
