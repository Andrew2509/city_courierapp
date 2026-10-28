import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Helper terstandarisasi untuk parsing response RajaOngkir / Komerce API.
/// Menjamin tidak pernah memunculkan 'UNKNOWN', memisahkan etd dari pickup schedule,
/// memformat ETD dengan benar tanpa 'day hari', dan memprioritaskan layanan Same-Day.
class RajaOngkirParser {
  /// Resolves the courier name cleanly from API fields.
  /// Never returns 'UNKNOWN', 'null', or empty string.
  static String resolveCourierName({
    String? name,
    String? code,
    String? service,
    String? description,
  }) {
    // 1. Cek jika name dari API sudah ada dan valid (bukan UNKNOWN/null/undefined)
    if (name != null) {
      final trimmed = name.trim();
      final upper = trimmed.toUpperCase();
      if (trimmed.isNotEmpty &&
          upper != 'UNKNOWN' &&
          upper != 'NULL' &&
          upper != 'UNDEFINED') {
        // Hapus kata UNKNOWN jika ada di dalam nama (misal "UNKNOWN JNE")
        String cleaned = trimmed.replaceAll(RegExp(r'\bunknown\b', caseSensitive: false), '').trim();
        if (cleaned.isNotEmpty) {
          return cleaned;
        }
      }
    }

    // 2. Mapping dari courier_code standar
    final c = (code ?? '').trim().toLowerCase();
    if (c.contains('jne')) return 'JNE';
    if (c.contains('sicepat')) return 'SiCepat';
    if (c.contains('jnt') || c.contains('j&t')) return 'J&T Express';
    if (c.contains('pos')) return 'POS Indonesia';
    if (c.contains('tiki')) return 'TIKI';
    if (c.contains('anteraja')) return 'AnterAja';
    if (c.contains('ninja')) return 'Ninja Xpress';
    if (c.contains('lion')) return 'Lion Parcel';
    if (c.contains('wahana')) return 'Wahana';
    if (c.contains('sap')) return 'SAP Express';
    if (c.contains('ide')) return 'ID Express';
    if (c.contains('gosend') || c.contains('instant') || c.contains('grab')) {
      return 'Instant Delivery';
    }

    // 3. Mapping alternatif dari nama service / description
    final s = (service ?? '').trim().toUpperCase();
    final d = (description ?? '').trim().toUpperCase();
    if (s.startsWith('JNE') || s.contains('JTR') || s.contains('REG') || s.contains('OKE')) {
      return 'JNE';
    }
    if (s.startsWith('SICEPAT') || s.contains('SIUNT') || s.contains('GOKIL') || s.contains('HALU')) {
      return 'SiCepat';
    }
    if (s.startsWith('J&T') || s.startsWith('JNT') || s.contains('EZ') || s.contains('ECO')) {
      return 'J&T Express';
    }
    if (s.contains('INSTANT') || d.contains('INSTANT') || s.contains('SAMEDAY') || d.contains('SAMEDAY')) {
      return 'Instant';
    }

    // 4. Fallback aman: jika ada kode tampilkan kode (uppercase), jika tidak ada tampilkan 'Kurir'
    if (c.isNotEmpty && c != 'unknown') {
      return c.toUpperCase();
    }
    return 'Kurir';
  }

  /// Memeriksa apakah suatu service tergolong Instant / Same-Day
  static bool isSameDay({String? service, String? description, String? etd}) {
    final s = (service ?? '').trim().toLowerCase();
    final d = (description ?? '').trim().toLowerCase();
    final e = (etd ?? '').trim().toLowerCase();

    return s.contains('instant') ||
        s.contains('sameday') ||
        s.contains('same day') ||
        s.contains('same-day') ||
        s == 'sd' ||
        d.contains('instant') ||
        d.contains('sameday') ||
        d.contains('same day') ||
        d.contains('same-day') ||
        e == 'instant' ||
        e == 'sameday' ||
        e == 'same day' ||
        e == '0' ||
        e == '0-0';
  }

  /// Format ETD (Estimated Time of Delivery) sesuai standar RajaOngkir.
  /// Menghilangkan duplikasi "day hari", menangani Same-Day, dan fallback jika kosong.
  static String formatEtd(String? rawEtd, {String? service, String? description}) {
    // 1. Cek Instant / Same-Day
    if (isSameDay(service: service, description: description, etd: rawEtd)) {
      return 'Tiba hari ini';
    }

    if (rawEtd == null) {
      return 'Estimasi tidak tersedia';
    }

    final trimmed = rawEtd.trim();
    final lower = trimmed.toLowerCase();

    // 2. Cek apakah kosong atau bernilai null/undefined/unknown
    if (trimmed.isEmpty ||
        lower == 'null' ||
        lower == 'undefined' ||
        lower == 'unknown' ||
        lower == '-' ||
        lower == 'n/a') {
      return 'Estimasi tidak tersedia';
    }

    // 3. Bersihkan string dari 'hari', 'days', 'day', 'estimasi'
    String clean = trimmed
        .replaceAll(RegExp(r'\b(days?|hari|estimasi)\b', caseSensitive: false), '')
        .replaceAll('-', '–') // gunakan en-dash rapi (–)
        .trim();

    if (clean.isEmpty) {
      return 'Estimasi tidak tersedia';
    }

    return 'Estimasi $clean hari';
  }

  /// Parsing harga / cost ke integer
  static int parsePrice(dynamic val) {
    if (val == null) return 0;
    if (val is num) return val.toInt();
    if (val is String) {
      final clean = val.replaceAll(RegExp(r'[^0-9]'), '');
      return int.tryParse(clean) ?? 0;
    }
    return 0;
  }

  /// Mengambil IconData yang sesuai dengan kode kurir
  static IconData getCourierIcon(String? code) {
    final c = (code ?? '').toLowerCase();
    if (c.contains('jne')) return Icons.local_shipping_outlined;
    if (c.contains('pos')) return Icons.markunread_mailbox_outlined;
    if (c.contains('tiki')) return Icons.delivery_dining_outlined;
    if (c.contains('sicepat')) return Icons.bolt_outlined;
    if (c.contains('jnt') || c.contains('j&t')) return Icons.rocket_launch_outlined;
    if (c.contains('instant') || c.contains('gosend') || c.contains('grab')) {
      return Icons.flash_on_outlined;
    }
    return Icons.local_shipping_outlined;
  }

  /// Parse response dinamis dari RajaOngkir / Komerce API (Nested maupun Flat).
  static List<Map<String, dynamic>> parseCouriers(dynamic responseData) {
    final List<Map<String, dynamic>> result = [];

    // Debug log response pada development environment (Sesuai Poin 10)
    if (kDebugMode) {
      debugPrint('[RajaOngkirParser] Parsing response data: $responseData');
    }

    List<dynamic> list = [];
    if (responseData is List) {
      list = responseData;
    } else if (responseData is Map) {
      if (responseData['data'] is List) {
        list = responseData['data'];
      } else if (responseData['results'] is List) {
        list = responseData['results'];
      } else if (responseData['rajaongkir'] != null &&
          responseData['rajaongkir'] is Map &&
          responseData['rajaongkir']['results'] is List) {
        list = responseData['rajaongkir']['results'];
      }
    }

    for (var raw in list) {
      if (raw is! Map) continue;
      final Map<String, dynamic> item = Map<String, dynamic>.from(raw);

      // Kasus 1: Nested RajaOngkir standard (memiliki 'costs' array)
      if (item['costs'] is List && (item['costs'] as List).isNotEmpty) {
        final rawCourierName = item['name']?.toString();
        final courierCode = item['code']?.toString() ?? '';

        for (var costEntry in item['costs']) {
          if (costEntry is! Map) continue;
          final serviceName = costEntry['service']?.toString() ?? '';
          final description = costEntry['description']?.toString() ?? '';

          int price = 0;
          String rawEtd = '';

          if (costEntry['cost'] is List && (costEntry['cost'] as List).isNotEmpty) {
            final firstCost = costEntry['cost'][0];
            if (firstCost is Map) {
              price = parsePrice(firstCost['value'] ?? firstCost['cost']);
              rawEtd = firstCost['etd']?.toString() ?? '';
            }
          } else if (costEntry['cost'] != null) {
            price = parsePrice(costEntry['cost']);
            rawEtd = costEntry['etd']?.toString() ?? '';
          }

          final courierName = resolveCourierName(
            name: rawCourierName,
            code: courierCode,
            service: serviceName,
            description: description,
          );

          final bool sameDay = isSameDay(
            service: serviceName,
            description: description,
            etd: rawEtd,
          );

          result.add({
            'code': courierCode,
            'name': courierName,
            'service': serviceName.isNotEmpty ? serviceName : 'REG',
            'description': description,
            'price': price,
            'etd': rawEtd,
            'duration': formatEtd(rawEtd, service: serviceName, description: description),
            'is_sameday': sameDay,
            'icon': getCourierIcon(courierCode),
          });
        }
      }
      // Kasus 2: Flat List (data[] langsung berisi: name, code, service, cost, etd)
      else {
        final rawCourierName = (item['name'] ?? item['courier_name'])?.toString();
        final courierCode = (item['code'] ?? item['courier_code'])?.toString() ?? '';
        final serviceName = (item['service'] ?? item['service_name'])?.toString() ?? '';
        final description = (item['description'] ?? item['service_description'])?.toString() ?? '';

        int price = parsePrice(item['cost'] ?? item['price'] ?? item['shipping_cost'] ?? item['value']);
        String rawEtd = (item['etd'] ?? item['estimated_delivery'] ?? item['duration'])?.toString() ?? '';

        if (price == 0 && item['cost'] is List && (item['cost'] as List).isNotEmpty) {
          final c = item['cost'][0];
          if (c is Map) {
            price = parsePrice(c['value'] ?? c['cost']);
            if (rawEtd.isEmpty) rawEtd = c['etd']?.toString() ?? '';
          }
        }

        final courierName = resolveCourierName(
          name: rawCourierName,
          code: courierCode,
          service: serviceName,
          description: description,
        );

        final bool sameDay = isSameDay(
          service: serviceName,
          description: description,
          etd: rawEtd,
        );

        result.add({
          'code': courierCode,
          'name': courierName,
          'service': serviceName.isNotEmpty ? serviceName : 'REG',
          'description': description,
          'price': price,
          'etd': rawEtd,
          'duration': formatEtd(rawEtd, service: serviceName, description: description),
          'is_sameday': sameDay,
          'icon': getCourierIcon(courierCode),
        });
      }
    }

    // Poin 5: Prioritaskan layanan Same-Day / Instant di urutan teratas
    result.sort((a, b) {
      final bool aSameDay = a['is_sameday'] == true;
      final bool bSameDay = b['is_sameday'] == true;
      if (aSameDay && !bSameDay) return -1;
      if (!aSameDay && bSameDay) return 1;
      return (a['price'] as int).compareTo(b['price'] as int);
    });

    return result;
  }
}
