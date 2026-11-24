import 'package:flutter/material.dart';

import 'package:city_courierapp/models/shipping/route_model.dart';
import 'package:city_courierapp/widgets/maps/traffic_overlay_widgets.dart';

/// Banner arah navigasi ringkas bergaya Google Maps:
/// kartu utama hijau-teal pekat dengan ikon manuver langsung & teks
/// `ke arah <Nama Jalan>`, serta tab kecil `Kemudian` + ikon manuver
/// berikutnya yang menempel di sudut kiri bawah.
class NavigationTurnBanner extends StatelessWidget {
  final RouteStep? currentStep;
  final RouteStep? thenStep;
  final String fallbackInstruction;
  final String distanceLabel;

  const NavigationTurnBanner({
    super.key,
    required this.currentStep,
    required this.fallbackInstruction,
    this.thenStep,
    this.distanceLabel = '',
  });

  static const Color bannerColor = Color(0xFF0A6051);
  static const Color thenTabColor = Color(0xFF07493E);

  /// Mengecek apakah manuver berupa jalan lurus / mulai berjalan.
  static bool isStraightOrDepart(String? maneuver) {
    final m = (maneuver ?? '').trim().toLowerCase();
    return m.isEmpty ||
        m == 'depart' ||
        m.contains('depart') ||
        m.contains('straight') ||
        m.contains('continue') ||
        m.contains('follow');
  }

  /// Memetakan kode manuver untuk tampilan banner agar `depart`/`continue`
  /// memakai panah lurus ke atas (`Icons.straight_rounded`).
  static IconData maneuverIcon(String? maneuver) {
    if (isStraightOrDepart(maneuver)) {
      return Icons.straight_rounded;
    }
    return navigationManeuverIcon(maneuver);
  }

  static String _turnPrefixForManeuver(String? maneuver) {
    final m = (maneuver ?? '').toLowerCase();
    if (m.contains('arrive')) return 'Tiba di';
    if (m.contains('uturn') || m.contains('u-turn')) return 'Putar balik ke';
    if (m.contains('roundabout')) return 'Bundaran ke';
    if (m.contains('sharp_left') || m.contains('sharp-left')) {
      return 'Belok tajam kiri ke';
    }
    if (m.contains('sharp_right') || m.contains('sharp-right')) {
      return 'Belok tajam kanan ke';
    }
    if (m.contains('slight_left') ||
        m.contains('slight-left') ||
        m.contains('bear_left') ||
        m.contains('keep_left')) {
      return 'Agak kiri ke';
    }
    if (m.contains('slight_right') ||
        m.contains('slight-right') ||
        m.contains('bear_right') ||
        m.contains('keep_right')) {
      return 'Agak kanan ke';
    }
    if (m.contains('left')) return 'Belok kiri ke';
    if (m.contains('right')) return 'Belok kanan ke';
    if (m.contains('merge')) return 'Gabung ke';
    if (m.contains('fork') || m.contains('exit')) return 'Ambil arah ke';
    return 'ke arah';
  }

  /// Menyusun pasangan `(prefixKecil, teksUtamaTebal)` agar konsisten dengan
  /// format ringkas seperti `ke arah Jl. Garuda`.
  static ({String? prefix, String mainText}) formatHeadline(
    RouteStep? step,
    String fallbackTitle,
  ) {
    final road = step?.roadName?.trim() ?? '';
    final maneuver = step?.maneuver;
    if (road.isNotEmpty) {
      final prefix = isStraightOrDepart(maneuver)
          ? 'ke arah'
          : _turnPrefixForManeuver(maneuver);
      return (prefix: prefix, mainText: road);
    }

    final raw = (step?.instruction ?? fallbackTitle).trim();
    final safeText = raw.isNotEmpty ? raw : fallbackTitle;
    final lower = safeText.toLowerCase();

    if (lower.startsWith('ke arah ')) {
      final tail = safeText.substring(8).trim();
      if (tail.isNotEmpty) {
        return (prefix: 'ke arah', mainText: tail);
      }
    }

    for (final connector in const [' menuju ', ' ke arah ', ' ke ']) {
      final idx = lower.indexOf(connector);
      if (idx > 0) {
        final head = safeText.substring(0, idx + connector.length).trim();
        final tail = safeText.substring(idx + connector.length).trim();
        if (tail.isNotEmpty) {
          return (prefix: head, mainText: tail);
        }
      }
    }

    return (prefix: null, mainText: safeText);
  }

  @override
  Widget build(BuildContext context) {
    final maneuver = currentStep?.maneuver;
    final headline = formatHeadline(currentStep, fallbackInstruction);
    final showTurnDistance =
        distanceLabel.trim().isNotEmpty && !isStraightOrDepart(maneuver);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: bannerColor,
            borderRadius: thenStep != null
                ? const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                  )
                : BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (showTurnDistance)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      maneuverIcon(maneuver),
                      color: Colors.white,
                      size: 30,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      distanceLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                )
              else
                Icon(
                  maneuverIcon(maneuver),
                  color: Colors.white,
                  size: 34,
                ),
              const SizedBox(width: 14),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      if (headline.prefix != null &&
                          headline.prefix!.isNotEmpty)
                        TextSpan(
                          text: '${headline.prefix} ',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.92),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      TextSpan(
                        text: headline.mainText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        if (thenStep != null)
          Container(
            key: const Key('nav_then_pill'),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: const BoxDecoration(
              color: thenTabColor,
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(14),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Kemudian',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  maneuverIcon(thenStep!.maneuver),
                  color: Colors.white,
                  size: 19,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
