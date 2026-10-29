import 'package:flutter/material.dart';
import 'package:city_courierapp/core/config/app_colors.dart';
import 'package:city_courierapp/services/wallet/wallet_service.dart';

/// OVO Linking Screen — Form Verifikasi & Penghubungan Akun OVO Kurir.
class OvoLinkingScreen extends StatefulWidget {
  final bool isUpdate;
  final String? initialPhone;
  final String? initialName;

  const OvoLinkingScreen({
    super.key,
    this.isUpdate = false,
    this.initialPhone,
    this.initialName,
  });

  @override
  State<OvoLinkingScreen> createState() => _OvoLinkingScreenState();
}

// Backward compatibility alias
typedef DanaLinkingScreen = OvoLinkingScreen;

class _OvoLinkingScreenState extends State<OvoLinkingScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  bool _consent = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialPhone != null) {
      _phoneController.text = widget.initialPhone!;
    }
    if (widget.initialName != null) {
      _nameController.text = widget.initialName!;
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  String? _validatePhone(String? val) {
    if (val == null || val.trim().isEmpty) {
      return 'Nomor HP OVO wajib diisi';
    }
    final clean = val.replaceAll(RegExp(r'[^0-9+]'), '');
    String normalized = clean;
    if (clean.startsWith('+62')) {
      normalized = '0${clean.substring(3)}';
    } else if (clean.startsWith('62')) {
      normalized = '0${clean.substring(2)}';
    }

    if (!RegExp(r'^08[0-9]{8,12}$').hasMatch(normalized)) {
      return 'Format nomor HP tidak valid (contoh: 081234567890)';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_consent) {
      setState(() {
        _errorMessage = 'Anda harus menyetujui penggunaan akun OVO untuk pencairan.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final phone = _phoneController.text.trim();
    final name = _nameController.text.trim();

    final result = widget.isUpdate
        ? await WalletService.updateOvo(
            phoneNumber: phone,
            accountName: name,
            consent: _consent,
          )
        : await WalletService.connectOvo(
            phoneNumber: phone,
            accountName: name,
            consent: _consent,
          );

    if (!mounted) return;

    if (result['success'] == true) {
      setState(() {
        _isSubmitting = false;
        _isSuccess = true;
      });

      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted) {
        Navigator.pop(context, true);
      }
    } else {
      setState(() {
        _isSubmitting = false;
        _errorMessage = result['message'] ?? 'Gagal memverifikasi akun OVO.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF191B23)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.isUpdate ? 'Ubah Nomor OVO' : 'Hubungkan Akun OVO',
          style: const TextStyle(
            color: Color(0xFF191B23),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOvoBanner(),
                const SizedBox(height: 24),
                if (_errorMessage != null) ...[
                  _buildErrorBanner(_errorMessage!),
                  const SizedBox(height: 16),
                ],
                if (_isSuccess) ...[
                  _buildSuccessBanner(),
                  const SizedBox(height: 16),
                ],
                _buildFormFields(),
                const SizedBox(height: 20),
                _buildConsentCheckbox(),
                const SizedBox(height: 20),
                _buildSecurityNotice(),
                const SizedBox(height: 32),
                _buildSubmitButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOvoBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF4C3494), // Ungu khas OVO
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4C3494).withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text(
                'ovo',
                style: TextStyle(
                  color: Color(0xFF4C3494),
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  letterSpacing: -1,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dompet Digital OVO',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Pendapatan pengantaran akan ditransfer langsung ke saldo OVO Anda.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFFB91C1C),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFDCFCE7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Akun OVO berhasil diverifikasi dan terhubung!',
              style: TextStyle(
                color: Color(0xFF15803D),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Nomor HP OVO',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          validator: _validatePhone,
          decoration: InputDecoration(
            hintText: 'Contoh: 081234567890',
            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
            prefixIcon: const Icon(Icons.phone_android, color: Color(0xFF64748B), size: 20),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF4C3494), width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Nama Pemilik Akun OVO',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          validator: (val) {
            if (val == null || val.trim().isEmpty) {
              return 'Nama pemilik akun OVO wajib diisi';
            }
            return null;
          },
          decoration: InputDecoration(
            hintText: 'Nama lengkap sesuai akun OVO',
            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
            prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF64748B), size: 20),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF4C3494), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConsentCheckbox() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _consent ? const Color(0xFF4C3494) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: _consent,
              activeColor: const Color(0xFF4C3494),
              onChanged: (val) => setState(() => _consent = val ?? false),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _consent = !_consent),
              child: const Text(
                'Saya menyetujui penggunaan akun OVO ini sebagai rekening resmi pencairan pendapatan di City Courier.',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF334155),
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityNotice() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: Color(0xFF0EA5E9), size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Keamanan Terjamin: City Courier tidak pernah meminta PIN, password, atau kode OTP OVO Anda.',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF64748B),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: _isSubmitting || _isSuccess ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4C3494),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Text(
                widget.isUpdate ? 'Simpan Perubahan' : 'Verifikasi & Hubungkan OVO',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}
