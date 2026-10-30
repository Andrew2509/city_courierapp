class PaymentResult {
  final String paymentId;
  final String method;
  final int amount;
  final String status;
  final String? qrString;
  final String? vaNumber;
  final String? checkoutUrl;
  final String? instructions;
  final DateTime? expiryTime;

  /// 'direct' (VA/QRIS dibuat server) atau 'redirect' (halaman iPaymu).
  final String paymentMode;

  PaymentResult({
    required this.paymentId,
    required this.method,
    required this.amount,
    required this.status,
    this.qrString,
    this.vaNumber,
    this.checkoutUrl,
    this.instructions,
    this.expiryTime,
    this.paymentMode = 'direct',
  });

  /// Pembayaran lewat halaman iPaymu: tidak ada nomor VA / QR dari server,
  /// hanya URL checkout yang harus dibuka pelanggan.
  bool get isRedirect =>
      paymentMode == 'redirect' ||
      (vaNumber == null &&
          qrString == null &&
          checkoutUrl != null &&
          checkoutUrl!.isNotEmpty);

  factory PaymentResult.fromJson(Map<String, dynamic> json) {
    return PaymentResult(
      paymentId: json['payment_id'] ?? '',
      method: json['method'] ?? '',
      amount: json['amount'] ?? 0,
      status: json['status'] ?? 'pending',
      qrString: json['qr_string'],
      vaNumber: json['va_number'],
      checkoutUrl: json['checkout_url'] ?? json['payment_url'],
      paymentMode: json['payment_mode'] ?? 'direct',
      instructions: json['instructions'] is List 
          ? (json['instructions'] as List).join('\n') 
          : json['instructions'],
      expiryTime: json['expiry_time'] != null 
          ? DateTime.parse(json['expiry_time']) 
          : (json['expired_at'] != null ? DateTime.parse(json['expired_at']) : null),
    );
  }
}
