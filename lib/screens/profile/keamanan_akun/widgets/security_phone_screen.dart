import 'dart:async';

import 'package:city_courierapp/models/security/account_security_models.dart';
import 'package:city_courierapp/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef RequestPhoneOtpFn = Future<Map<String, dynamic>> Function(String phone);
typedef VerifyPhoneOtpFn = Future<Map<String, dynamic>> Function(
  String phone,
  String otp,
);

class SecurityPhoneScreen extends StatefulWidget {
  final SecurityUserInfo user;
  final RequestPhoneOtpFn? onRequestPhoneOtp;
  final VerifyPhoneOtpFn? onVerifyPhoneOtp;
  final Future<void> Function() onPhoneUpdated;
  final VoidCallback onBack;
  final void Function(String message, {bool isError}) onNotify;

  const SecurityPhoneScreen({
    super.key,
    required this.user,
    this.onRequestPhoneOtp,
    this.onVerifyPhoneOtp,
    required this.onPhoneUpdated,
    required this.onBack,
    required this.onNotify,
  });

  @override
  State<SecurityPhoneScreen> createState() => _SecurityPhoneScreenState();
}

class _SecurityPhoneScreenState extends State<SecurityPhoneScreen> {
  Future<void> _openPhoneModal() async {
    final requestOtp = widget.onRequestPhoneOtp ?? ApiService.requestPhoneOtp;
    final verifyOtp = widget.onVerifyPhoneOtp ??
        (String phone, String otp) => ApiService.verifyPhoneOtp(phone, otp);

    final updated = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ChangePhoneOtpDialog(
        currentPhone: widget.user.phone,
        onRequestOtp: requestOtp,
        onVerifyOtp: verifyOtp,
      ),
    );

    if (updated == true && mounted) {
      await widget.onPhoneUpdated();
      widget.onNotify('Nomor telepon berhasil diperbarui dan diverifikasi!');
    }
  }

  @override
  Widget build(BuildContext context) {
    final verified = widget.user.phoneVerified;
    final displayPhone = widget.user.phoneFormatted ??
        formatIndonesianPhoneDisplay(widget.user.phone) ??
        'Belum diatur';

    return ColoredBox(
      color: Colors.white,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Color(0xFFF1F5F9)),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: widget.onBack,
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const Expanded(
                  child: Text(
                    'Verifikasi Akun',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: verified
                        ? const Color(0xFFECFDF5)
                        : const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: verified
                          ? const Color(0xFFA7F3D0)
                          : const Color(0xFFFDE68A),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: verified
                              ? const Color(0xFF10B981)
                              : const Color(0xFFF59E0B),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          verified
                              ? Icons.check_rounded
                              : Icons.warning_amber_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              verified
                                  ? 'Identitas Terverifikasi'
                                  : 'Verifikasi Diperlukan',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: verified
                                    ? const Color(0xFF064E3B)
                                    : const Color(0xFF78350F),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              verified
                                  ? 'Nomor telepon akun Anda telah aktif dan terhubung ke sistem keamanan City Courier.'
                                  : 'Verifikasi nomor telepon via OTP WhatsApp untuk meningkatkan keamanan akun Anda.',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: verified
                                    ? const Color(0xFF065F46)
                                    : const Color(0xFF92400E),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'NOMOR TELEPON TERDAFTAR',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayPhone,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1E293B),
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  verified
                                      ? 'Terverifikasi via WhatsApp OTP'
                                      : 'Menunggu verifikasi OTP WhatsApp',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: verified
                                        ? const Color(0xFF059669)
                                        : const Color(0xFFD97706),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton(
                            onPressed: _openPhoneModal,
                            style: OutlinedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFF7ED),
                              foregroundColor: const Color(0xFFEA580C),
                              side: const BorderSide(color: Color(0xFFFED7AA)),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              verified ? 'Ubah' : 'Verifikasi',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Penting untuk Diketahui',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF334155),
                        ),
                      ),
                      SizedBox(height: 8),
                      _BulletPoint(
                        text:
                            'Pengubahan nomor HP membutuhkan verifikasi kode OTP 6 digit ke WhatsApp.',
                      ),
                      SizedBox(height: 6),
                      _BulletPoint(
                        text:
                            'Satu nomor telepon hanya dapat terhubung ke 1 akun City Courier aktif.',
                      ),
                      SizedBox(height: 6),
                      _BulletPoint(
                        text:
                            'Nomor terverifikasi digunakan untuk login cepat OTP dan pemulihan PIN transaksi.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BulletPoint extends StatelessWidget {
  final String text;
  const _BulletPoint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 5),
          child: Icon(Icons.circle, size: 5, color: Color(0xFF64748B)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 11.5,
              color: Color(0xFF475569),
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

class _ChangePhoneOtpDialog extends StatefulWidget {
  final String? currentPhone;
  final RequestPhoneOtpFn onRequestOtp;
  final VerifyPhoneOtpFn onVerifyOtp;

  const _ChangePhoneOtpDialog({
    this.currentPhone,
    required this.onRequestOtp,
    required this.onVerifyOtp,
  });

  @override
  State<_ChangePhoneOtpDialog> createState() => _ChangePhoneOtpDialogState();
}

class _ChangePhoneOtpDialogState extends State<_ChangePhoneOtpDialog> {
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _otpCtrl = TextEditingController();

  bool _otpSent = false;
  bool _loading = false;
  String? _errorText;
  String _submittedPhone = '';
  int _cooldown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  String _toLocalPhone(String raw) {
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('0062')) {
      digits = '0${digits.substring(4)}';
    } else if (digits.startsWith('62')) {
      digits = '0${digits.substring(2)}';
    } else if (!digits.startsWith('0') && digits.isNotEmpty) {
      digits = '0$digits';
    }
    return digits;
  }

  void _startCooldown(int seconds) {
    _timer?.cancel();
    setState(() => _cooldown = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cooldown <= 1) {
        timer.cancel();
        setState(() => _cooldown = 0);
      } else {
        setState(() => _cooldown--);
      }
    });
  }

  Future<void> _sendOtp() async {
    final normalized = _toLocalPhone(_phoneCtrl.text);
    if (normalized.length < 10 || !normalized.startsWith('08')) {
      setState(() {
        _errorText =
            'Masukkan nomor HP Indonesia yang valid (contoh: 812-3456-7890).';
      });
      return;
    }

    setState(() {
      _loading = true;
      _errorText = null;
    });

    final res = await widget.onRequestOtp(normalized);
    if (!mounted) return;
    setState(() => _loading = false);

    if (res['success'] == true) {
      if (res['already_verified'] == true) {
        Navigator.pop(context, true);
        return;
      }
      final retryAfter = (res['retry_after'] as num?)?.toInt() ?? 60;
      _startCooldown(retryAfter);
      setState(() {
        _submittedPhone = normalized;
        _otpSent = true;
      });
    } else {
      final retry = (res['retry_after'] as num?)?.toInt() ?? 0;
      if (retry > 0 && _cooldown == 0) _startCooldown(retry);
      setState(() {
        _errorText = (res['message'] ?? 'Gagal mengirim kode OTP.').toString();
      });
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (otp.length < 4) {
      setState(() => _errorText = 'Masukkan kode OTP 6 digit dari WhatsApp.');
      return;
    }

    setState(() {
      _loading = true;
      _errorText = null;
    });

    final res = await widget.onVerifyOtp(_submittedPhone, otp);
    if (!mounted) return;
    setState(() => _loading = false);

    if (res['success'] == true) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _errorText = (res['message'] ?? 'Kode OTP salah.').toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _otpSent ? 'Verifikasi Kode OTP' : 'Ubah Nomor Telepon',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _otpSent
                  ? 'Masukkan kode OTP yang dikirim via WhatsApp ke $_submittedPhone.'
                  : 'Masukkan nomor HP baru Anda. Kode OTP verifikasi akan dikirimkan.',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            if (!_otpSent) ...[
              const Text(
                'Nomor Telepon Baru',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                clipBehavior: Clip.antiAlias,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5F9),
                        border: Border(
                          right: BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                      child: const Text(
                        '+62',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9\- ]')),
                        ],
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                        decoration: const InputDecoration(
                          hintText: '812-3456-7890',
                          hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const Text(
                'Kode OTP (6 Digit)',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _otpCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 6,
                  color: Color(0xFF1E293B),
                ),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '••••••',
                  hintStyle: const TextStyle(color: Color(0xFFCBD5E1)),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFFF97316),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: (_loading || _cooldown > 0) ? null : _sendOtp,
                  child: Text(
                    _cooldown > 0
                        ? 'Kirim ulang (${_cooldown}d)'
                        : 'Kirim Ulang OTP',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
            if (_errorText != null) ...[
              const SizedBox(height: 10),
              Text(
                _errorText!,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFE11D48),
                ),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _loading
                        ? null
                        : () {
                            if (_otpSent) {
                              setState(() {
                                _otpSent = false;
                                _errorText = null;
                                _otpCtrl.clear();
                              });
                            } else {
                              Navigator.pop(context, false);
                            }
                          },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF475569),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _otpSent ? 'Ubah Nomor' : 'Batal',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _loading
                        ? null
                        : (_otpSent ? _verifyOtp : _sendOtp),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF97316),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _otpSent ? 'Verifikasi' : 'Kirim OTP & Simpan',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
