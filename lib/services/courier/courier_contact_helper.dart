import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Helper terpadu bagi kurir untuk menghubungi pengirim maupun penerima
/// melalui WhatsApp chat maupun panggilan telepon.
class CourierContactHelper {
  CourierContactHelper._();

  static const Color whatsappColor = Color(0xFF16A34A);
  static const Color whatsappBgColor = Color(0xFFE8F7EE);
  static const Color whatsappBorderColor = Color(0xFF22C55E);

  /// Menormalkan nomor telepon Indonesia menjadi format digit `62...` untuk `wa.me`.
  static String? normalizeWhatsAppNumber(String? rawPhone) {
    if (rawPhone == null) return null;
    var digits = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;

    if (digits.startsWith('00')) {
      digits = digits.substring(2);
    }
    if (digits.startsWith('0')) {
      digits = '62${digits.substring(1)}';
    } else if (digits.startsWith('8')) {
      digits = '62$digits';
    }

    if (digits.length < 8) return null;
    return digits;
  }

  /// Membangun pesan pembuka otomatis sesuai konteks pengirim / penerima.
  static String buildGreetingMessage({
    required bool isSender,
    Map<String, dynamic>? order,
  }) {
    final nestedShip =
        order?['shipment'] is Map ? order!['shipment'] as Map : null;
    final resiRaw = order?['tracking_number'] ??
        order?['order_number'] ??
        order?['shipment_number'] ??
        nestedShip?['tracking_number'] ??
        nestedShip?['shipment_number'] ??
        order?['id'];
    final resi = (resiRaw != null && resiRaw.toString().trim().isNotEmpty)
        ? ' (${resiRaw.toString().trim()})'
        : '';

    final rawName = isSender
        ? (order?['sender_name'] ?? order?['pickup_name'] ?? order?['customer_name'])
        : (order?['receiver_name'] ??
            order?['recipient_name'] ??
            order?['dropoff_name']);
    final name = (rawName != null && rawName.toString().trim().isNotEmpty)
        ? ' ${rawName.toString().trim()}'
        : '';

    if (isSender) {
      return 'Halo$name, saya kurir City Courier untuk pesanan$resi sedang menuju lokasi penjemputan paket Anda.';
    }
    return 'Halo$name, saya kurir City Courier untuk pesanan$resi sedang menuju lokasi pengantaran paket Anda.';
  }

  /// Membentuk URI web universal `https://wa.me/...`.
  static Uri? buildWhatsAppUri(String? rawPhone, {String? message}) {
    final digits = normalizeWhatsAppNumber(rawPhone);
    if (digits == null) return null;
    final text = message?.trim();
    if (text != null && text.isNotEmpty) {
      return Uri.parse(
        'https://wa.me/$digits?text=${Uri.encodeComponent(text)}',
      );
    }
    return Uri.parse('https://wa.me/$digits');
  }

  /// Membentuk URI aplikasi `whatsapp://send?...`.
  static Uri? buildWhatsAppAppUri(String? rawPhone, {String? message}) {
    final digits = normalizeWhatsAppNumber(rawPhone);
    if (digits == null) return null;
    final text = message?.trim();
    if (text != null && text.isNotEmpty) {
      return Uri.parse(
        'whatsapp://send?phone=$digits&text=${Uri.encodeComponent(text)}',
      );
    }
    return Uri.parse('whatsapp://send?phone=$digits');
  }

  /// Mengambil nomor telepon pengirim dari struktur map order yang beragam.
  static String? extractSenderPhone(Map<String, dynamic>? order) {
    if (order == null) return null;
    for (final key in const ['sender_phone', 'pickup_phone', 'customer_phone']) {
      final v = order[key]?.toString().trim();
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  }

  /// Mengambil nomor telepon penerima dari struktur map order yang beragam.
  static String? extractReceiverPhone(Map<String, dynamic>? order) {
    if (order == null) return null;
    for (final key in const [
      'receiver_phone',
      'recipient_phone',
      'dropoff_phone',
    ]) {
      final v = order[key]?.toString().trim();
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  }

  /// Membuka chat WhatsApp dengan prioritas app native lalu fallback ke `wa.me`.
  static Future<bool> openWhatsAppChat(
    BuildContext context, {
    required String? phone,
    bool isSender = false,
    Map<String, dynamic>? order,
    String? customMessage,
  }) async {
    final msg = customMessage ??
        buildGreetingMessage(isSender: isSender, order: order);
    final appUri = buildWhatsAppAppUri(phone, message: msg);
    final webUri = buildWhatsAppUri(phone, message: msg);

    if (appUri == null || webUri == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nomor WhatsApp tidak tersedia')),
        );
      }
      return false;
    }

    try {
      if (await canLaunchUrl(appUri)) {
        final launched = await launchUrl(
          appUri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) return true;
      }
      if (await canLaunchUrl(webUri)) {
        final launched = await launchUrl(
          webUri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) return true;
      }
    } catch (_) {}

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak dapat membuka aplikasi WhatsApp'),
        ),
      );
    }
    return false;
  }

  /// Membuka langsung kontak nomor tujuan di WhatsApp (tanpa isi pesan teks)
  /// agar kurir dapat langsung menelepon via WA, dengan fallback ke dialer
  /// seluler `tel:` apabila WhatsApp tidak terpasang.
  static Future<bool> callPhone(
    BuildContext context,
    String? rawPhone, {
    Future<bool> Function(Uri uri)? canLaunchOverride,
    Future<bool> Function(Uri uri, {LaunchMode mode})? launchOverride,
  }) async {
    final canLaunch = canLaunchOverride ?? canLaunchUrl;
    Future<bool> doLaunch(
      Uri uri, {
      LaunchMode mode = LaunchMode.platformDefault,
    }) {
      return launchOverride != null
          ? launchOverride(uri, mode: mode)
          : launchUrl(uri, mode: mode);
    }

    final waAppUri = buildWhatsAppAppUri(rawPhone);
    final clean = rawPhone?.replaceAll(RegExp(r'[^0-9+]'), '') ?? '';
    if (waAppUri == null && clean.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nomor telepon tidak tersedia')),
        );
      }
      return false;
    }

    if (waAppUri != null) {
      try {
        if (await canLaunch(waAppUri)) {
          final launched = await doLaunch(
            waAppUri,
            mode: LaunchMode.externalApplication,
          );
          if (launched) return true;
        }
      } catch (_) {}
    }

    if (clean.isNotEmpty) {
      final telUri = Uri(scheme: 'tel', path: clean);
      try {
        if (await canLaunch(telUri)) {
          final launched = await doLaunch(telUri);
          if (launched) return true;
        }
      } catch (_) {}
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak dapat membuka WhatsApp atau aplikasi telepon'),
        ),
      );
    }
    return false;
  }
}

/// Tombol ikon kontak bergaya City Courier (dipakai bersama oleh WA & Telepon).
class _CourierActionIconButton extends StatelessWidget {
  final VoidCallback onTap;
  final String tooltip;
  final double size;
  final bool isCircular;
  final Color bgColor;
  final Color borderColor;
  final Widget icon;

  const _CourierActionIconButton({
    required this.onTap,
    required this.tooltip,
    required this.size,
    required this.isCircular,
    required this.bgColor,
    required this.borderColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(isCircular ? size / 2 : 12);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: bgColor,
        shape: isCircular
            ? const CircleBorder()
            : RoundedRectangleBorder(borderRadius: radius),
        child: InkWell(
          onTap: onTap,
          customBorder: isCircular
              ? const CircleBorder()
              : RoundedRectangleBorder(borderRadius: radius),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: isCircular ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: isCircular ? null : radius,
              border: Border.all(color: borderColor),
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
  final String tooltip;
  final double size;
  final double iconSize;
  final bool isCircular;

  const CourierWhatsAppIconButton({
    super.key,
    required this.onTap,
    required this.tooltip,
    this.size = 40,
    this.iconSize = 19,
    this.isCircular = false,
  });

  @override
  Widget build(BuildContext context) {
    return _CourierActionIconButton(
      onTap: onTap,
      tooltip: tooltip,
      size: size,
      isCircular: isCircular,
      bgColor: CourierContactHelper.whatsappBgColor,
      borderColor:
          CourierContactHelper.whatsappBorderColor.withValues(alpha: 0.45),
      icon: FaIcon(
        FontAwesomeIcons.whatsapp,
        size: iconSize,
        color: CourierContactHelper.whatsappColor,
      ),
    );
  }
}

/// Tombol ikon panggilan telepon ringkas bergaya City Courier.
class CourierPhoneIconButton extends StatelessWidget {
  final VoidCallback onTap;
  final String tooltip;
  final double size;
  final double iconSize;
  final bool isCircular;
  final Color iconColor;
  final Color bgColor;
  final Color borderColor;

  const CourierPhoneIconButton({
    super.key,
    required this.onTap,
    required this.tooltip,
    this.size = 40,
    this.iconSize = 19,
    this.isCircular = false,
    this.iconColor = const Color(0xFFFF5A00),
    this.bgColor = const Color(0xFFFFF4EC),
    this.borderColor = const Color(0xFFFF5A00),
  });

  @override
  Widget build(BuildContext context) {
    return _CourierActionIconButton(
      onTap: onTap,
      tooltip: tooltip,
      size: size,
      isCircular: isCircular,
      bgColor: bgColor,
      borderColor: borderColor.withValues(alpha: 0.45),
      icon: Icon(Icons.phone_rounded, size: iconSize, color: iconColor),
    );
  }
}
