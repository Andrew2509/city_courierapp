import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

enum WhatsAppContactRole { customer, sender, receiver, courier, support }

/// Helper tunggal untuk seluruh komunikasi City Courier via WhatsApp.
/// Tidak menyediakan panggilan telepon (tel:), VoIP, atau chat internal.
class CourierContactHelper {
  CourierContactHelper._();

  static const Color whatsappColor = Color(0xFF16A34A);
  static const Color whatsappBgColor = Color(0xFFE8F7EE);
  static const Color whatsappBorderColor = Color(0xFF22C55E);

  /// Menormalkan nomor WhatsApp Indonesia ke format internasional `628xxxxxxxxxx`
  /// tanpa `+`, spasi, tanda hubung, atau karakter khusus lainnya.
  /// Mengembalikan `null` jika nomor kosong atau formatnya tidak valid.
  static String? normalizeWhatsAppNumber(String? rawPhone) {
    if (rawPhone == null) return null;
    final trimmed = rawPhone.trim();
    if (trimmed.isEmpty) return null;

    // Tolak input yang mengandung huruf atau karakter tak terduga.
    if (RegExp(r'[a-zA-Z]').hasMatch(trimmed)) {
      return null;
    }

    var digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null;

    if (digits.startsWith('0062')) {
      digits = digits.substring(2);
    } else if (digits.startsWith('0')) {
      digits = '62${digits.substring(1)}';
    } else if (digits.startsWith('8')) {
      digits = '62$digits';
    }

    // Nomor WhatsApp Indonesia valid diawali `628` (10–15 digit total).
    if (!RegExp(r'^628\d{7,12}$').hasMatch(digits)) {
      return null;
    }
    return digits;
  }

  /// Menjelaskan status validasi nomor telepon untuk notifikasi pengguna.
  static String? validateWhatsAppNumberError(String? rawPhone) {
    if (rawPhone == null || rawPhone.trim().isEmpty) {
      return 'Nomor WhatsApp belum tersedia';
    }
    if (normalizeWhatsAppNumber(rawPhone) == null) {
      return 'Format nomor WhatsApp tidak valid';
    }
    return null;
  }

  /// Membentuk URL universal WhatsApp `https://wa.me/628xxxxxxxxxx`
  /// dengan pesan otomatis opsional (tetap dikirim manual oleh pengguna).
  static Uri? buildWhatsAppUri(String? rawPhone, {String? message}) {
    final digits = normalizeWhatsAppNumber(rawPhone);
    if (digits == null) return null;

    final text = (message ?? '').trim();
    if (text.isNotEmpty) {
      return Uri.parse(
        'https://wa.me/$digits?text=${Uri.encodeComponent(text)}',
      );
    }
    return Uri.parse('https://wa.me/$digits');
  }

  /// Membentuk URI deep link aplikasi WhatsApp / WhatsApp Business `whatsapp://send?...`.
  static Uri? buildWhatsAppAppUri(String? rawPhone, {String? message}) {
    final digits = normalizeWhatsAppNumber(rawPhone);
    if (digits == null) return null;

    final text = (message ?? '').trim();
    if (text.isNotEmpty) {
      return Uri.parse(
        'whatsapp://send?phone=$digits&text=${Uri.encodeComponent(text)}',
      );
    }
    return Uri.parse('whatsapp://send?phone=$digits');
  }

  /// Membangun pesan sapaan kontekstual sesuai peran kontak & detail pesanan.
  static String buildGreetingMessage({
    WhatsAppContactRole? role,
    bool? isSender,
    Map<String, dynamic>? order,
    String? trackingNumber,
    String? contactName,
  }) {
    final resolvedRole =
        role ??
        (isSender == true
            ? WhatsAppContactRole.sender
            : (isSender == false ? WhatsAppContactRole.receiver : null));

    final rawResi =
        trackingNumber ??
        order?['tracking_number'] ??
        order?['order_number'] ??
        order?['shipment_number'] ??
        '';
    final resi = rawResi.toString().trim();
    final resiTag = resi.isNotEmpty && resi != '-' ? ' ($resi)' : '';

    final resolvedName = (contactName ?? _extractNameForRole(resolvedRole, order) ?? '').trim();
    final greetingPrefix = resolvedName.isNotEmpty ? 'Halo $resolvedName' : 'Halo';

    switch (resolvedRole) {
      case WhatsAppContactRole.sender:
        return '$greetingPrefix, saya kurir City Courier. Saya menghubungi terkait penjemputan paket pesanan$resiTag Anda.';
      case WhatsAppContactRole.receiver:
        return '$greetingPrefix, saya kurir City Courier. Saya menghubungi terkait pengantaran paket$resiTag Anda.';
      case WhatsAppContactRole.customer:
        return '$greetingPrefix, saya kurir City Courier. Saya menghubungi terkait pesanan$resiTag Anda.';
      case WhatsAppContactRole.courier:
        return '$greetingPrefix, saya customer City Courier. Saya menghubungi terkait pesanan$resiTag.';
      case WhatsAppContactRole.support:
        return 'Halo Customer Service City Courier, saya ingin bertanya terkait pesanan$resiTag.';
      case null:
        return 'Halo, saya dari City Courier ingin mengonfirmasi pengantaran pesanan$resiTag.';
    }
  }

  static String? _extractNameForRole(
    WhatsAppContactRole? role,
    Map<String, dynamic>? order,
  ) {
    if (order == null || role == null) return null;
    final nested = order['shipment'] is Map ? order['shipment'] as Map : null;
    String? pick(List<String> keys) {
      for (final k in keys) {
        final v = (order[k] ?? nested?[k])?.toString().trim();
        if (v != null && v.isNotEmpty && v != '-') return v;
      }
      return null;
    }

    switch (role) {
      case WhatsAppContactRole.sender:
        return pick(const ['sender_name', 'pickup_name']);
      case WhatsAppContactRole.receiver:
        return pick(const ['receiver_name', 'recipient_name', 'dropoff_name']);
      case WhatsAppContactRole.customer:
        return pick(const ['customer_name', 'sender_name']);
      case WhatsAppContactRole.courier:
        final cMap = order['courier'] is Map ? order['courier'] as Map : null;
        return cMap?['name']?.toString().trim() ??
            pick(const ['courier_name']);
      case WhatsAppContactRole.support:
        return null;
    }
  }

  /// Membuka WhatsApp / WhatsApp Business atau fallback ke `https://wa.me/628xxxxxxxxxx`.
  /// Menampilkan notifikasi jika nomor tidak tersedia, format tidak valid, atau gagal dibuka.
  static Future<bool> openWhatsAppChat(
    BuildContext context, {
    required String? phone,
    WhatsAppContactRole? role,
    bool? isSender,
    Map<String, dynamic>? order,
    String? trackingNumber,
    String? contactName,
    String? customMessage,
    Future<bool> Function(Uri uri)? canLaunchOverride,
    Future<bool> Function(Uri uri, {LaunchMode mode})? launchOverride,
  }) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final validationError = validateWhatsAppNumberError(phone);
    if (validationError != null) {
      messenger?.showSnackBar(
        SnackBar(
          content: Text(validationError),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade700,
        ),
      );
      return false;
    }

    final msg =
        (customMessage != null && customMessage.trim().isNotEmpty)
            ? customMessage.trim()
            : buildGreetingMessage(
                role: role,
                isSender: isSender,
                order: order,
                trackingNumber: trackingNumber,
                contactName: contactName,
              );

    final webUri = buildWhatsAppUri(phone, message: msg)!;
    final appUri = buildWhatsAppAppUri(phone, message: msg)!;

    Future<bool> tryLaunch(Uri uri, LaunchMode mode) async {
      try {
        if (launchOverride != null) {
          return await launchOverride(uri, mode: mode);
        }
        return await launchUrl(uri, mode: mode);
      } catch (_) {
        return false;
      }
    }

    // 1. Prioritaskan URL universal `https://wa.me/628...` via externalApplication
    //    agar langsung membuka WhatsApp / WA Business atau browser jika belum terpasang.
    if (await tryLaunch(webUri, LaunchMode.externalApplication)) {
      return true;
    }

    // 2. Fallback scheme native `whatsapp://send?phone=628...` bila terpasang.
    final canOpenApp =
        canLaunchOverride != null
            ? await canLaunchOverride(appUri)
            : await canLaunchUrl(appUri);
    if (canOpenApp && await tryLaunch(appUri, LaunchMode.externalApplication)) {
      return true;
    }

    // 3. Fallback tautan platform default agar tetap berfungsi meski WhatsApp belum terpasang.
    if (await tryLaunch(webUri, LaunchMode.platformDefault)) {
      return true;
    }

    messenger?.showSnackBar(
      const SnackBar(
        content: Text('Tidak dapat membuka tautan WhatsApp'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return false;
  }

  /// Mengambil nomor pengirim, penerima, customer, dan label terbaik dari map order/shipment.
  static String? extractPhone(Map<String, dynamic>? data, List<String> keys) {
    if (data == null) return null;
    for (final k in keys) {
      final raw = data[k]?.toString().trim();
      if (raw != null && raw.isNotEmpty && raw != '-') {
        return raw;
      }
      final nested = data['shipment'];
      if (nested is Map) {
        final nestedRaw = nested[k]?.toString().trim();
        if (nestedRaw != null && nestedRaw.isNotEmpty && nestedRaw != '-') {
          return nestedRaw;
        }
      }
    }
    return null;
  }

  /// Mengambil nomor pengirim (sender) terbaik dari map order/shipment.
  static String? extractSenderPhone(Map<String, dynamic>? data) {
    return extractPhone(data, const [
      'sender_phone',
      'pickup_phone',
      'customer_phone',
      'phone',
    ]);
  }

  /// Mengambil nomor penerima (receiver) terbaik dari map order/shipment.
  static String? extractReceiverPhone(Map<String, dynamic>? data) {
    return extractPhone(data, const [
      'receiver_phone',
      'recipient_phone',
      'dropoff_phone',
      'destination_phone',
      'customer_phone',
    ]);
  }

  /// Mengambil nomor customer terbaik dari map order/shipment.
  static String? extractCustomerPhone(Map<String, dynamic>? data) {
    return extractPhone(data, const [
      'customer_phone',
      'sender_phone',
      'phone',
    ]);
  }
}

/// Widget lingkaran/rounded seragam untuk tombol aksi ikon WhatsApp.
class _ContactCircleButton extends StatelessWidget {
  final Color bgColor;
  final Color borderColor;
  final Widget icon;
  final String tooltip;
  final double size;
  final bool isCircular;
  final VoidCallback onTap;

  const _ContactCircleButton({
    required this.bgColor,
    required this.borderColor,
    required this.icon,
    required this.tooltip,
    required this.size,
    required this.isCircular,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(isCircular ? size / 2 : size * 0.28);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Ink(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: bgColor,
              shape: isCircular ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: isCircular ? null : radius,
              border: Border.all(color: borderColor, width: 1),
            ),
            child: Center(child: icon),
          ),
        ),
      ),
    );
  }
}

/// Tombol ikon WhatsApp hijau bersih bergaya City Courier.
class CourierWhatsAppIconButton extends StatelessWidget {
  final VoidCallback onTap;
  final double size;
  final double iconSize;
  final String tooltip;
  final bool isCircular;

  const CourierWhatsAppIconButton({
    super.key,
    required this.onTap,
    this.size = 38,
    this.iconSize = 18,
    this.tooltip = 'Hubungi via WhatsApp',
    this.isCircular = true,
  });

  @override
  Widget build(BuildContext context) {
    return _ContactCircleButton(
      bgColor: CourierContactHelper.whatsappBgColor,
      borderColor: CourierContactHelper.whatsappBorderColor.withValues(
        alpha: 0.45,
      ),
      tooltip: tooltip,
      size: size,
      isCircular: isCircular,
      onTap: onTap,
      icon: FaIcon(
        FontAwesomeIcons.whatsapp,
        size: iconSize,
        color: CourierContactHelper.whatsappColor,
      ),
    );
  }
}
