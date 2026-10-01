class PaymentMethod {
  final String code;
  final String name;
  final String group;
  final String iconUrl;
  final int fee;
  final bool isAvailable;

  PaymentMethod({
    required this.code,
    required this.name,
    required this.group,
    required this.iconUrl,
    required this.fee,
    required this.isAvailable,
  });

  factory PaymentMethod.fromJson(Map<String, dynamic> json) {
    String code = (json['code'] ?? json['channel_code'] ?? json['id'] ?? json['method'] ?? '').toString();
    String name = (json['name'] ?? json['channel_name'] ?? json['title'] ?? json['display_name'] ?? '').toString();
    
    // If name is empty, try to derive it from code
    if (name.isEmpty && code.isNotEmpty) {
      name = code.replaceAll('_', ' ').replaceAll('-', ' ').toUpperCase();
    }
    
    // CRITICAL: If code is empty but name exists, use name as code to ensure uniqueness for selection
    if (code.isEmpty && name.isNotEmpty) {
      code = name.toLowerCase().replaceAll(' ', '_');
    }

    String iconUrl = (json['icon'] ?? json['icon_url'] ?? json['image_url'] ?? json['logo_url'] ?? '').toString();
    
    // Fallback logos if iconUrl is empty
    if (iconUrl.isEmpty || !iconUrl.startsWith('http')) {
      final String upperCode = code.toUpperCase();
      if (upperCode.contains('BCA')) {
        iconUrl = 'https://upload.wikimedia.org/wikipedia/commons/thumb/5/5c/Bank_Central_Asia.svg/1200px-Bank_Central_Asia.svg.png';
      } else if (upperCode.contains('BNI')) {
        iconUrl = 'https://upload.wikimedia.org/wikipedia/id/thumb/5/55/BNI_logo.svg/1200px-BNI_logo.svg.png';
      } else if (upperCode.contains('BRI')) {
        iconUrl = 'https://upload.wikimedia.org/wikipedia/commons/thumb/2/2e/BRI_Logo.svg/1200px-BRI_Logo.svg.png';
      } else if (upperCode.contains('MANDIRI')) {
        iconUrl = 'https://upload.wikimedia.org/wikipedia/commons/thumb/a/ad/Bank_Mandiri_logo_2016.svg/1200px-Bank_Mandiri_logo_2016.svg.png';
      } else if (upperCode.contains('PERMATA')) {
        iconUrl = 'https://upload.wikimedia.org/wikipedia/id/thumb/0/09/Logo_Bank_Permata.svg/1200px-Logo_Bank_Permata.svg.png';
      } else if (upperCode.contains('DANAMON')) {
        iconUrl = 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c7/Logo_Bank_Danamon.svg/1200px-Logo_Bank_Danamon.svg.png';
      } else if (upperCode.contains('CIMB')) {
        iconUrl = 'https://upload.wikimedia.org/wikipedia/commons/thumb/3/38/CIMB_Niaga_logo.svg/1200px-CIMB_Niaga_logo.svg.png';
      } else if (upperCode.contains('QRIS')) {
        iconUrl = 'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a2/Logo_QRIS.svg/1200px-Logo_QRIS.svg.png';
      } else if (upperCode.contains('DANA')) {
        iconUrl = 'https://upload.wikimedia.org/wikipedia/commons/thumb/7/72/Logo_dana_blue.svg/1200px-Logo_dana_blue.svg.png';
      } else if (upperCode.contains('OVO')) {
        iconUrl = 'https://upload.wikimedia.org/wikipedia/commons/thumb/e/eb/Logo_ovo_purple.svg/1200px-Logo_ovo_purple.svg.png';
      } else if (upperCode.contains('SHOPEE') || upperCode.contains('SPAY')) {
        iconUrl = 'https://upload.wikimedia.org/wikipedia/commons/thumb/f/fe/Shopee.svg/1200px-Shopee.svg.png';
      } else if (upperCode.contains('LINKAJA')) {
        iconUrl = 'https://upload.wikimedia.org/wikipedia/commons/thumb/8/85/LinkAja.svg/1200px-LinkAja.svg.png';
      }
    }

    return PaymentMethod(
      code: code,
      name: name.isEmpty ? 'Metode Pembayaran' : name,
      group: (json['group'] ?? json['payment_type'] ?? json['category'] ?? 'other').toString(),
      iconUrl: iconUrl,
      fee: int.tryParse(json['fee']?.toString() ?? '0') ?? 0,
      isAvailable: json['is_available'] == true || json['is_available'] == 1 || json['is_available'] == null,
    );
  }
}
