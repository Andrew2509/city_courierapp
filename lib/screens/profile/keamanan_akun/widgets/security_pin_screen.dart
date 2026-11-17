import 'dart:async';

import 'package:flutter/material.dart';

enum _PinFlowStep {
  verifyCurrent,
  verifyOtp,
  enterNew,
  confirmNew,
}

class SecurityPinScreen extends StatefulWidget {
  final bool hasExistingPin;
  final bool hasVerifiedPhone;
  final String? maskedPhone;
  final Future<bool> Function(String pin)? onVerifyCurrentPin;
  final Future<({bool ok, String message, int retryAfter})> Function()?
      onRequestPinResetOtp;
  final Future<({bool ok, String message})> Function({
    required String newPin,
    required String confirmPin,
    String? currentPin,
    String? otp,
  }) onSubmitPin;
  final VoidCallback onBack;
  final void Function(String message, {bool isError}) onNotify;

  const SecurityPinScreen({
    super.key,
    required this.hasExistingPin,
    required this.hasVerifiedPhone,
    this.maskedPhone,
    this.onVerifyCurrentPin,
    this.onRequestPinResetOtp,
    required this.onSubmitPin,
    required this.onBack,
    required this.onNotify,
  });

  @override
  State<SecurityPinScreen> createState() => _SecurityPinScreenState();
}

class _SecurityPinScreenState extends State<SecurityPinScreen> {
  static const Color _primaryOrange = Color(0xFFF97316);

  late _PinFlowStep _step;
  String _input = '';
  String _currentPin = '';
  String _resetOtp = '';
  String _newPin = '';
  bool _submitting = false;
  bool _sendingOtp = false;
  String? _inlineError;
  int _otpCooldown = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _resetFlow();
  }

  @override
  void didUpdateWidget(covariant SecurityPinScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hasExistingPin != widget.hasExistingPin &&
        _input.isEmpty &&
        _newPin.isEmpty) {
      _resetFlow();
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _resetFlow() {
    _step = widget.hasExistingPin
        ? _PinFlowStep.verifyCurrent
        : _PinFlowStep.enterNew;
    _input = '';
    _currentPin = '';
    _resetOtp = '';
    _newPin = '';
    _inlineError = null;
  }

  bool _isWeakPin(String pin) {
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) return true;
    if (RegExp(r'^(\d)\1{5}$').hasMatch(pin)) return true;
    final digits = pin.split('').map(int.parse).toList();
    var asc = true;
    var desc = true;
    for (var i = 1; i < 6; i++) {
      if (digits[i] - digits[i - 1] != 1) asc = false;
      if (digits[i] - digits[i - 1] != -1) desc = false;
    }
    return asc || desc;
  }

  String get _stepTitle {
    switch (_step) {
      case _PinFlowStep.verifyCurrent:
        return 'Masukkan PIN Saat Ini';
      case _PinFlowStep.verifyOtp:
        return 'Masukkan 6 Digit Kode OTP';
      case _PinFlowStep.enterNew:
        return 'Masukkan PIN Baru';
      case _PinFlowStep.confirmNew:
        return 'Konfirmasi PIN Baru';
    }
  }

  String get _stepDesc {
    switch (_step) {
      case _PinFlowStep.verifyCurrent:
        return 'Verifikasi 6 digit PIN transaksi lama sebelum mengubah ke PIN baru';
      case _PinFlowStep.verifyOtp:
        return 'Masukkan kode OTP WhatsApp yang dikirim ke ${widget.maskedPhone ?? "nomor terdaftar"}';
      case _PinFlowStep.enterNew:
        return 'PIN digunakan untuk verifikasi pembayaran City Wallet dan aktivitas akun';
      case _PinFlowStep.confirmNew:
        return 'Masukkan kembali 6 digit PIN baru untuk konfirmasi';
    }
  }

  String get _primaryButtonLabel {
    switch (_step) {
      case _PinFlowStep.verifyCurrent:
        return 'Lanjutkan Verifikasi';
      case _PinFlowStep.verifyOtp:
        return 'Konfirmasi OTP & Lanjutkan';
      case _PinFlowStep.enterNew:
        return 'Lanjut Konfirmasi PIN';
      case _PinFlowStep.confirmNew:
        return 'Simpan PIN Baru';
    }
  }

  void _pressDigit(String digit) {
    if (_submitting || _input.length >= 6) return;
    setState(() {
      _inlineError = null;
      _input += digit;
    });
    if (_input.length == 6 && _step == _PinFlowStep.enterNew) {
      if (_isWeakPin(_input)) {
        setState(() {
          _inlineError =
              'Hindari angka berurutan (123456) atau berulang (111111).';
        });
        return;
      }
    }
  }

  void _deleteDigit() {
    if (_submitting || _input.isEmpty) return;
    setState(() {
      _inlineError = null;
      _input = _input.substring(0, _input.length - 1);
    });
  }

  void _clearDigits() {
    if (_submitting) return;
    setState(() {
      _inlineError = null;
      _input = '';
    });
  }

  void _startOtpCooldown(int seconds) {
    _cooldownTimer?.cancel();
    setState(() => _otpCooldown = seconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_otpCooldown <= 1) {
        timer.cancel();
        setState(() => _otpCooldown = 0);
      } else {
        setState(() => _otpCooldown--);
      }
    });
  }

  Future<void> _switchToForgotPinOtp() async {
    if (!widget.hasVerifiedPhone) {
      widget.onNotify(
        'Nomor telepon harus terverifikasi sebelum menggunakan Lupa PIN.',
        isError: true,
      );
      return;
    }
    if (widget.onRequestPinResetOtp == null) return;

    setState(() {
      _sendingOtp = true;
      _inlineError = null;
    });
    final res = await widget.onRequestPinResetOtp!();
    if (!mounted) return;
    setState(() => _sendingOtp = false);

    if (res.ok) {
      _startOtpCooldown(res.retryAfter);
      setState(() {
        _step = _PinFlowStep.verifyOtp;
        _input = '';
        _currentPin = '';
      });
      widget.onNotify(res.message);
    } else {
      if (res.retryAfter > 0 && _otpCooldown == 0) {
        _startOtpCooldown(res.retryAfter);
      }
      setState(() => _inlineError = res.message);
      widget.onNotify(res.message, isError: true);
    }
  }

  Future<void> _handleSubmit() async {
    if (_submitting) return;
    if (_input.length != 6) {
      widget.onNotify('Silakan masukkan 6 digit angka terlebih dahulu.',
          isError: true);
      return;
    }

    if (_step == _PinFlowStep.verifyCurrent) {
      if (widget.onVerifyCurrentPin != null) {
        setState(() {
          _submitting = true;
          _inlineError = null;
        });
        try {
          final ok = await widget.onVerifyCurrentPin!(_input);
          if (!mounted) return;
          if (!ok) {
            setState(() {
              _submitting = false;
              _inlineError = 'PIN saat ini tidak sesuai.';
              _input = '';
            });
            return;
          }
        } catch (e) {
          if (!mounted) return;
          setState(() {
            _submitting = false;
            _inlineError = e.toString();
            _input = '';
          });
          return;
        }
      }
      setState(() {
        _submitting = false;
        _currentPin = _input;
        _input = '';
        _step = _PinFlowStep.enterNew;
      });
      return;
    }

    if (_step == _PinFlowStep.verifyOtp) {
      setState(() {
        _resetOtp = _input;
        _input = '';
        _step = _PinFlowStep.enterNew;
        _inlineError = null;
      });
      return;
    }

    if (_step == _PinFlowStep.enterNew) {
      if (_isWeakPin(_input)) {
        setState(() {
          _inlineError =
              'Hindari angka berurutan (123456) atau berulang (111111).';
        });
        return;
      }
      if (_currentPin.isNotEmpty && _input == _currentPin) {
        setState(() {
          _inlineError = 'PIN baru tidak boleh sama dengan PIN saat ini.';
        });
        return;
      }
      setState(() {
        _newPin = _input;
        _input = '';
        _step = _PinFlowStep.confirmNew;
        _inlineError = null;
      });
      return;
    }

    if (_step == _PinFlowStep.confirmNew) {
      if (_input != _newPin) {
        setState(() {
          _inlineError = 'Konfirmasi PIN tidak cocok. Silakan ulangi.';
          _input = '';
        });
        return;
      }

      setState(() {
        _submitting = true;
        _inlineError = null;
      });

      final res = await widget.onSubmitPin(
        newPin: _newPin,
        confirmPin: _input,
        currentPin: _currentPin.isNotEmpty ? _currentPin : null,
        otp: _resetOtp.isNotEmpty ? _resetOtp : null,
      );

      if (!mounted) return;
      setState(() => _submitting = false);

      if (res.ok) {
        _resetFlow();
        widget.onNotify(res.message);
        widget.onBack();
      } else {
        setState(() {
          _inlineError = res.message;
          if (_resetOtp.isNotEmpty) {
            _step = _PinFlowStep.verifyOtp;
            _input = '';
          } else {
            _input = '';
          }
        });
        widget.onNotify(res.message, isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  onPressed: () {
                    if (_step == _PinFlowStep.confirmNew) {
                      setState(() {
                        _step = _PinFlowStep.enterNew;
                        _input = '';
                        _inlineError = null;
                      });
                    } else {
                      _resetFlow();
                      widget.onBack();
                    }
                  },
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Color(0xFF1E293B),
                  ),
                ),
                Expanded(
                  child: Text(
                    widget.hasExistingPin
                        ? 'Ubah PIN Transaksi'
                        : 'Buat PIN Transaksi',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEDD5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.lock_outline_rounded,
                      color: Color(0xFFEA580C),
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _stepTitle,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 290),
                    child: Text(
                      _stepDesc,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(6, (index) {
                      final filled = index < _input.length;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: filled ? _primaryOrange : Colors.transparent,
                          border: Border.all(
                            color: filled
                                ? _primaryOrange
                                : const Color(0xFFCBD5E1),
                            width: 2,
                          ),
                        ),
                      );
                    }),
                  ),
                  if (_inlineError != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFECDD3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: Color(0xFFE11D48),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _inlineError!,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF9F1239),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (_step == _PinFlowStep.verifyCurrent &&
                      widget.hasVerifiedPhone)
                    TextButton(
                      onPressed: _sendingOtp ? null : _switchToForgotPinOtp,
                      child: _sendingOtp
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'Lupa PIN Saat Ini? Reset via OTP WhatsApp',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFEA580C),
                              ),
                            ),
                    )
                  else if (_step == _PinFlowStep.verifyOtp)
                    TextButton(
                      onPressed: (_sendingOtp || _otpCooldown > 0)
                          ? null
                          : _switchToForgotPinOtp,
                      child: Text(
                        _otpCooldown > 0
                            ? 'Kirim ulang OTP dalam ${_otpCooldown}d'
                            : 'Kirim Ulang Kode OTP',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _otpCooldown > 0
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFFEA580C),
                        ),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_rounded,
                          color: Color(0xFFD97706),
                          size: 16,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Hindari angka berurutan (123456) atau berulang demi keamanan akun Anda.',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF92400E),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 280),
                    child: GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.75,
                      children: [
                        for (final digit in [
                          '1',
                          '2',
                          '3',
                          '4',
                          '5',
                          '6',
                          '7',
                          '8',
                          '9',
                        ])
                          _PinKeypadKey(
                            key: ValueKey('pin-key-$digit'),
                            label: digit,
                            onTap: () => _pressDigit(digit),
                          ),
                        _PinKeypadKey(
                          key: const ValueKey('pin-key-clear'),
                          label: 'C',
                          isSecondary: true,
                          onTap: _clearDigits,
                        ),
                        _PinKeypadKey(
                          key: const ValueKey('pin-key-0'),
                          label: '0',
                          onTap: () => _pressDigit('0'),
                        ),
                        _PinKeypadKey(
                          key: const ValueKey('pin-key-back'),
                          icon: Icons.backspace_outlined,
                          isSecondary: true,
                          onTap: _deleteDigit,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryOrange,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _primaryButtonLabel,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PinKeypadKey extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final bool isSecondary;
  final VoidCallback onTap;

  const _PinKeypadKey({
    super.key,
    this.label,
    this.icon,
    this.isSecondary = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSecondary ? const Color(0xFFF8FAFC) : const Color(0xFFF1F5F9),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Center(
          child: icon != null
              ? Icon(icon, size: 20, color: const Color(0xFF334155))
              : Text(
                  label ?? '',
                  style: TextStyle(
                    fontSize: isSecondary ? 13 : 18,
                    fontWeight: FontWeight.w800,
                    color: isSecondary
                        ? const Color(0xFF64748B)
                        : const Color(0xFF1E293B),
                  ),
                ),
        ),
      ),
    );
  }
}
