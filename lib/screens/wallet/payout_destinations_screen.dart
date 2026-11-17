import 'package:city_courierapp/core/config/app_colors.dart';
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

  static const _bankChannels = [
    ('ID_BCA', 'Bank BCA'),
    ('ID_BRI', 'Bank BRI'),
    ('ID_BNI', 'Bank BNI'),
    ('ID_MANDIRI', 'Bank Mandiri'),
    ('ID_PERMATA', 'Bank Permata'),
    ('ID_BSI', 'Bank BSI'),
  ];

  static const _ewalletChannels = [
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
      final list = await _service.getDestinations();
      if (!mounted) return;
      setState(() {
        _items = list;
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
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
      backgroundColor: AppColors.backgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            CityWalletUi.buildHeader(context, title: 'Rekening & E-Wallet'),
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
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            children: [
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryOrange
                                      .withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.primaryOrange
                                        .withValues(alpha: 0.25),
                                  ),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.verified_user_outlined,
                                      size: 20,
                                      color: AppColors.primaryOrange,
                                    ),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Pilih akun utama atau tambahkan rekening bank / e-wallet untuk penarikan dana.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: CityWalletUi.inkPrimary,
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
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: CityWalletUi.borderColor,
                                    ),
                                  ),
                                  child: const Column(
                                    children: [
                                      Icon(
                                        Icons.account_balance_wallet_outlined,
                                        size: 38,
                                        color: Color(0xFFCBD5E1),
                                      ),
                                      SizedBox(height: 10),
                                      Text(
                                        'Belum ada rekening bank atau e-wallet terdaftar',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                          color: CityWalletUi.inkPrimary,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Tekan tombol di bawah untuk menambahkan rekening tujuan baru.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: CityWalletUi.inkSecondary,
                                        ),
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
                              AppColors.primaryOrange.withValues(alpha: 0.45),
                          fgColor: AppColors.primaryOrange,
                        ),
                        icon: const Icon(Icons.account_balance_outlined,
                            size: 18),
                        label: const Text(
                          '+ Rekening Bank',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _openAddSheet(initialType: 'ewallet'),
                        style: CityWalletUi.primaryButtonStyle(),
                        icon: const Icon(
                          Icons.account_balance_wallet_outlined,
                          size: 18,
                        ),
                        label: const Text(
                          '+ E-Wallet',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDestinationCard(PayoutDestinationV1 d) {
    final isBank = d.destinationType == 'bank';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              d.isDefault ? AppColors.primaryOrange : CityWalletUi.borderColor,
          width: d.isDefault ? 1.4 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isBank
                  ? AppColors.primaryOrange.withValues(alpha: 0.1)
                  : const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isBank
                  ? Icons.account_balance_outlined
                  : Icons.account_balance_wallet_outlined,
              size: 20,
              color: isBank ? AppColors.primaryOrange : const Color(0xFF15803D),
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
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: CityWalletUi.inkPrimary,
                        ),
                      ),
                    ),
                    if (d.isDefault) ...[
                      const SizedBox(width: 6),
                      const WalletStatusChip(status: 'default'),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${d.accountNumberMasked} • ${d.accountHolderName}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: CityWalletUi.inkSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (d.isDefault)
            const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF16A34A),
              size: 22,
            )
          else
            TextButton(
              onPressed: () async {
                await _service.setDefaultDestination(d.id);
                _load();
              },
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryOrange,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: AppColors.primaryOrange.withValues(alpha: 0.35),
                  ),
                ),
              ),
              child: const Text(
                'Jadikan Default',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
              ),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryOrange.withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color:
                selected ? AppColors.primaryOrange : CityWalletUi.borderColor,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color:
                  selected ? AppColors.primaryOrange : CityWalletUi.inkSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: selected
                    ? AppColors.primaryOrange
                    : CityWalletUi.inkPrimary,
              ),
            ),
          ],
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
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Tambah Rekening / E-Wallet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: CityWalletUi.inkPrimary,
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
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              key: ValueKey(_destType),
              initialValue: _channelCode,
              isExpanded: true,
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: CityWalletUi.inkSecondary,
              ),
              decoration: CityWalletUi.inputDecoration(
                hintText: 'Pilih bank atau e-wallet',
              ),
              items: channels
                  .map(
                    (c) => DropdownMenuItem(
                      value: c.$1,
                      child: Text(
                        c.$2,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: CityWalletUi.inkPrimary,
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
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _numCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => _scheduleInquiry(),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: CityWalletUi.inkPrimary,
              ),
              decoration: CityWalletUi.inputDecoration(
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
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.characters,
              onChanged: (val) => _inquiry.onManualNameEdited(val),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: CityWalletUi.inkPrimary,
              ),
              decoration: CityWalletUi.inputDecoration(
                hintText: 'Nama pemilik sesuai akun',
              ),
            ),
            if (_sheetError != null) ...[
              const SizedBox(height: 10),
              Text(
                _sheetError!,
                style: const TextStyle(
                  fontSize: 12,
                  color: CityWalletUi.errorRed,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: CityWalletUi.primaryButtonStyle(enabled: !_saving),
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
                      'Simpan Rekening Tujuan',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
