import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:city_courierapp/core/config/app_colors.dart';
import 'package:city_courierapp/core/utils/currency_format.dart';
import 'package:city_courierapp/screens/courier/ci_word/wallet/status_penarikan_screen.dart';
import 'package:city_courierapp/services/wallet/wallet_service.dart';

/// Tarik Saldo ke DANA.
///
/// Tidak ada binding akun: kurir mengetik nomor DANA tujuan pada setiap
/// penarikan (format 08… atau 628…, dinormalisasi validasi di backend).
///
/// Alur: saldo → nomor tujuan → nominal → validasi (min/max/saldo) →
/// rincian biaya dari backend → konfirmasi → POST /api/courier/withdrawals →
/// layar status.
///
/// Keamanan: idempotency key dibuat sekali per (nominal, nomor) dan dipakai
/// ulang bila hasil request tidak pasti (timeout/5xx). Request tidak dikirim
/// ulang dengan key baru sebelum status transaksi diperiksa.
class TarikDanaScreen extends StatefulWidget {
  const TarikDanaScreen({super.key});

  @override
  State<TarikDanaScreen> createState() => _TarikDanaScreenState();
}

/// Formatter input nominal agar tampil dengan separator ribuan ("500.000").
class _RupiahInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(text: '');
    }

    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      buffer.write(digits[i]);
      final remaining = digits.length - i - 1;
      if (remaining > 0 && remaining % 3 == 0) {
        buffer.write('.');
      }
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _TarikDanaScreenState extends State<TarikDanaScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final FocusNode _phoneFocus = FocusNode();

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _loadError;

  double _saldoTersedia = 0;
  WithdrawalFeeConfig? _feeConfig;

  /// Idempotency key yang sudah dipakai untuk (nominal, nomor) yang sama.
  /// Dipakai ulang supaya percobaan ulang setelah timeout tidak membuat
  /// penarikan kedua.
  String? _pendingKey;
  double? _pendingAmount;
  String? _pendingPhone;

  @override
  void initState() {
    super.initState();
    _phoneFocus.addListener(() => setState(() {}));
    _loadData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _phoneController.dispose();
    _nameController.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    final results = await Future.wait([
      WalletService.getWallet(),
      WalletService.getFeeConfig(),
    ]);

    if (!mounted) return;

    final walletResult = results[0];
    final feeResult = results[1];

    setState(() {
      _isLoading = false;

      _saldoTersedia = walletResult['success'] == true && walletResult['data'] != null
          ? WalletBalance.fromJson((walletResult['data'] as Map).cast<String, dynamic>())
              .availableBalance
          : 0;

      // Biaya & batas HARUS dari backend. Tanpa konfigurasi, penarikan
      // ditahan agar tidak menampilkan biaya statis yang belum tentu benar.
      _feeConfig = feeResult['success'] == true && feeResult['data'] != null
          ? WithdrawalFeeConfig.fromJson(
              (feeResult['data'] as Map).cast<String, dynamic>())
          : null;

      if (walletResult['success'] != true) {
        _loadError = walletResult['message']?.toString() ?? 'Gagal memuat saldo';
      }
    });
  }

  double get _amount {
    return double.tryParse(
          _amountController.text.replaceAll('.', '').replaceAll(',', ''),
        ) ??
        0;
  }

  /// Nomor DANA yang diketik kurir (normalisasi hanya untuk validasi/preview;
  /// nomor asli dikirim apa adanya dan dinormalisasi final di backend).
  String? get _normalizedPhone =>
      WalletService.normalizePhone(_phoneController.text);

  String get _maskedPhone =>
      _normalizedPhone != null
          ? WalletService.maskPhone(_normalizedPhone)
          : '';

  String? get _phoneName {
    final name = _nameController.text.trim();
    return name.isEmpty ? null : name;
  }

  double get _fee => _feeConfig?.adminFee ?? 0;

  double get _netAmount {
    final net = _amount - _fee;
    return net > 0 ? net : 0;
  }

  bool get _feeConfigReady => _feeConfig != null;

  String? get _phoneError {
    final text = _phoneController.text.trim();
    if (text.isEmpty) return null; // diperiksa di _validationError
    if (_normalizedPhone == null) {
      return 'Nomor tidak valid. Gunakan format 08… atau 628… (9-13 digit setelah 62/0).';
    }
    return null;
  }

  String? get _validationError {
    if (!_feeConfigReady) {
      return 'Konfigurasi penarikan belum tersedia. Coba lagi nanti.';
    }
    if (_phoneController.text.trim().isEmpty) {
      return 'Masukkan nomor DANA tujuan.';
    }
    if (_normalizedPhone == null) {
      return 'Nomor DANA tidak valid. Gunakan format 08… atau 628….';
    }
    if (_amount <= 0) return 'Masukkan nominal penarikan.';

    final config = _feeConfig!;
    if (_amount < config.minimum) {
      return 'Minimum penarikan ${formatRupiah(config.minimum)}.';
    }
    if (_amount > config.maximum) {
      return 'Maksimum penarikan ${formatRupiah(config.maximum)}.';
    }
    if (_amount > _saldoTersedia) return 'Saldo tersedia tidak mencukupi.';
    if (_amount - _fee <= 0) return 'Nominal harus lebih besar dari biaya admin.';
    return null;
  }

  bool get _canSubmit => !_isSubmitting && _validationError == null;

  void _onAmountChanged(String value) {
    setState(() {
      _resetPendingKeyIfIdentityChanged();
    });
  }

  void _onDestinationChanged(String value) {
    setState(() {
      _resetPendingKeyIfIdentityChanged();
    });
  }

  /// (Nominal, nomor tujuan) berubah → transaksi berbeda, key lama tidak
  /// berlaku lagi.
  void _resetPendingKeyIfIdentityChanged() {
    if (_pendingKey == null) return;
    final phoneChanged =
        _pendingPhone != null && _pendingPhone != _phoneController.text.trim();
    final amountChanged = _pendingAmount != null && _amount != _pendingAmount;

    if (amountChanged || phoneChanged) {
      _pendingKey = null;
      _pendingAmount = null;
      _pendingPhone = null;
    }
  }

  Future<void> _confirm() async {
    if (_isSubmitting) return;

    final error = _validationError;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: const Color(0xFFDC2626)),
      );
      return;
    }

    final masked = _maskedPhone;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Konfirmasi Penarikan',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF191B23),
                ),
              ),
              const SizedBox(height: 14),
              _buildRow('Nominal', formatRupiah(_amount)),
              _buildRow('Biaya admin', formatRupiah(_fee)),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(height: 1, color: Color(0xFFF1F5F9)),
              ),
              _buildRow('Dana diterima', formatRupiah(_netAmount), bold: true),
              const SizedBox(height: 6),
              _buildRow('Tujuan', 'DANA'),
              _buildRow('Nomor', masked),
              if (_phoneName != null) _buildRow('Nama', _phoneName!),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Ya, Tarik Sekarang',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Pastikan nomor sudah benar. Saldo hanya dipotong setelah '
                'permintaan dibuat, dan status akhir mengikuti konfirmasi '
                'resmi dari penyedia.',
                style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true) await _submit();
  }

  Widget _buildRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
              color: const Color(0xFF191B23),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);

    final phone = _phoneController.text.trim();
    final masked = _maskedPhone.isEmpty ? '-' : _maskedPhone;
    final reusedKey =
        _pendingKey != null && _pendingAmount == _amount && _pendingPhone == phone;
    final key = reusedKey ? _pendingKey! : WalletService.generateIdempotencyKey();
    _pendingKey = key;
    _pendingAmount = _amount;
    _pendingPhone = phone;

    final result = await WalletService.createWithdrawal(
      amount: _amount,
      idempotencyKey: key,
      destinationPhone: phone,
    );

    if (!mounted) return;

    setState(() => _isSubmitting = false);

    if (result['success'] == true) {
      final data = result['data'] as Map<String, dynamic>?;
      final reference = (data?['idempotency_key'] ?? key).toString();
      final serverMasked =
          (data?['destination'] ?? data?['masked_account'] ?? data?['destination_masked'])
              ?.toString();

      _pendingKey = null;
      _pendingAmount = null;
      _pendingPhone = null;

      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => StatusPenarikanScreen(
            transactionId: reference,
            amount: _amount,
            bankName: 'DANA',
            maskedAccount: (serverMasked != null && serverMasked.isNotEmpty)
                ? serverMasked
                : masked,
            time: DateTime.now(),
          ),
        ),
      );
      return;
    }

    // Hasil tidak pasti (timeout / 5xx): jangan kirim ulang dengan key baru.
    if (result['uncertain'] == true) {
      if (!mounted) return;
      await _showUncertainDialog(key);
      return;
    }

    _pendingKey = null;
    _pendingAmount = null;
    _pendingPhone = null;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message']?.toString() ?? 'Gagal melakukan penarikan'),
        backgroundColor: const Color(0xFFDC2626),
      ),
    );
    await _loadData();
  }

  Future<void> _showUncertainDialog(String key) async {
    final check = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Status belum terkonfirmasi',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        content: const Text(
          'Koneksi terputus saat mengirim permintaan. Periksa status penarikan '
          'terlebih dahulu — jangan mengirim ulang sebelum statusnya diketahui.',
          style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Nanti', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Periksa Status'),
          ),
        ],
      ),
    );

    if (check == true && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StatusPenarikanScreen(
            transactionId: key,
            amount: _amount,
            bankName: 'DANA',
            maskedAccount: _maskedPhone.isEmpty ? '-' : _maskedPhone,
            time: DateTime.now(),
          ),
        ),
      );
      if (mounted) await _loadData();
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
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.primaryOrange),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_loadError != null) ...[
                            _buildLoadError(),
                            const SizedBox(height: 16),
                          ],
                          _buildSaldoCard(),
                          const SizedBox(height: 20),
                          _buildDestination(),
                          const SizedBox(height: 20),
                          _buildAmountSection(),
                          const SizedBox(height: 20),
                          _buildSummary(),
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Color(0xFF191B23)),
          ),
          const Expanded(
            child: Text(
              'Tarik Saldo',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF191B23),
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildLoadError() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 18, color: Color(0xFFDC2626)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _loadError!,
              style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaldoCard() {
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
          const Text(
            'Saldo tersedia',
            style: TextStyle(fontSize: 11.5, color: Colors.white70),
          ),
          const SizedBox(height: 4),
          Text(
            formatRupiah(_saldoTersedia),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDestination() {
    final phoneError = _phoneError;
    final hasFocus = _phoneFocus.hasFocus;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Nomor DANA Tujuan',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF191B23),
                ),
              ),
            ),
            // Ejaan bantuan
            const Text(
              'Nomor diketik setiap penarikan',
              style: TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _phoneController,
          focusNode: _phoneFocus,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(15),
          ],
          enabled: _feeConfigReady,
          onChanged: _onDestinationChanged,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: phoneError != null ? const Color(0xFFDC2626) : const Color(0xFF191B23),
          ),
          decoration: InputDecoration(
            prefixIcon: _buildDanaBadge(),
            hintText: '08xxxxxxxxxx',
            hintStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Color(0xFFE2E8F0),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE8E8E8)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: phoneError != null ? const Color(0xFFFECACA) : const Color(0xFFE8E8E8),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: phoneError != null
                    ? const Color(0xFFDC2626)
                    : AppColors.primaryOrange,
                width: 1.5,
              ),
            ),
            suffixIcon: hasFocus && _phoneController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18, color: Color(0xFF94A3B8)),
                    onPressed: () {
                      _phoneController.clear();
                      _onDestinationChanged('');
                    },
                  )
                : null,
          ),
        ),
        if (phoneError != null) ...[
          const SizedBox(height: 6),
          Text(phoneError, style: const TextStyle(fontSize: 11.5, color: Color(0xFFDC2626))),
        ] else ...[
          const SizedBox(height: 6),
          Text(
            'Contoh: 081234567890 atau 6281234567890.',
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
          ),
        ],
        const SizedBox(height: 10),
        // Nama pemilik (opsional) supaya kurir bisa cek ulang identitas tujuan.
        TextField(
          controller: _nameController,
          textCapitalization: TextCapitalization.characters,
          enabled: _feeConfigReady,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: 'Nama pemilik DANA (opsional)',
            hintStyle: const TextStyle(fontSize: 13.5, color: Color(0xFFBDCEDE)),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE8E8E8)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE8E8E8)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primaryOrange, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDanaBadge() {
    return Container(
      margin: const EdgeInsets.only(left: 12, right: 10),
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: const Color(0xFF118EEA),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Text(
          'D',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildAmountSection() {
    final minimum = _feeConfig?.minimum;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Nominal Penarikan',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF191B23),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _amountController,
          keyboardType: TextInputType.number,
          inputFormatters: [_RupiahInputFormatter()],
          enabled: _feeConfigReady,
          onChanged: _onAmountChanged,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF191B23),
          ),
          decoration: InputDecoration(
            prefixText: 'Rp ',
            prefixStyle: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF94A3B8),
            ),
            hintText: '0',
            hintStyle: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFFE2E8F0),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE8E8E8)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE8E8E8)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primaryOrange, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildQuickChip('Tarik semua', _saldoTersedia),
            if (_saldoTersedia >= 100000) _buildQuickChip('Rp 100.000', 100000),
            if (_saldoTersedia >= 500000) _buildQuickChip('Rp 500.000', 500000),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          minimum != null
              ? 'Minimal ${formatRupiah(minimum)} • Maksimal ${formatRupiah(_feeConfig!.maximum)}'
              : 'Batas penarikan belum tersedia dari server.',
          style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
        ),
      ],
    );
  }

  Widget _buildQuickChip(String label, double value) {
    final enabled = value > 0 && _feeConfigReady;
    final selected = _amount == value && value > 0;

    return ActionChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: !enabled
              ? const Color(0xFFCBD5E1)
              : (selected ? AppColors.primaryOrange : const Color(0xFF64748B)),
        ),
      ),
      backgroundColor: selected
          ? AppColors.primaryOrange.withOpacity(0.08)
          : Colors.white,
      side: BorderSide(
        color: selected ? AppColors.primaryOrange : const Color(0xFFE8E8E8),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onPressed: enabled
          ? () {
              setState(() {
                _amountController.text = formatRupiahDigits(value);
                _onAmountChanged(_amountController.text);
              });
            }
          : null,
    );
  }

  Widget _buildSummary() {
    final error = _validationError;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Rincian',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF191B23),
            ),
          ),
          const SizedBox(height: 10),
          _buildRow('Nominal penarikan', formatRupiah(_amount)),
          _buildRow(
            'Biaya admin',
            _feeConfigReady ? formatRupiah(_fee) : 'Belum tersedia',
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1, color: Color(0xFFF1F5F9)),
          ),
          _buildRow('Total diterima', formatRupiah(_netAmount), bold: true),
          _buildRow(
            'Tujuan',
            _maskedPhone.isEmpty ? 'Belum diisi' : 'DANA $_maskedPhone',
          ),
          if (error != null && _amount > 0) ...[
            const SizedBox(height: 10),
            Text(
              error,
              style: const TextStyle(fontSize: 11.5, color: Color(0xFFDC2626)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final canSubmit = _canSubmit && !_isLoading;

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: canSubmit ? _confirm : null,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    canSubmit ? AppColors.primaryOrange : const Color(0xFFF1F5F9),
                foregroundColor: canSubmit ? Colors.white : const Color(0xFF94A3B8),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Konfirmasi Penarikan',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 12, color: Color(0xFF94A3B8)),
              SizedBox(width: 4),
              Text(
                'Saldo dipotong hanya saat permintaan dibuat; status akhir '
                'mengikuti konfirmasi resmi penyedia.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8), height: 1.3),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
