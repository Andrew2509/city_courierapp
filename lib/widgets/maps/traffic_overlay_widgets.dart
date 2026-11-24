import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import 'package:city_courierapp/controllers/traffic_controller.dart';
import 'package:city_courierapp/core/config/app_colors.dart';
import 'package:city_courierapp/core/config/app_typography.dart';
import 'package:city_courierapp/models/maps/traffic_models.dart';
import 'package:city_courierapp/models/shipping/route_model.dart';
import 'package:city_courierapp/services/maps/traffic_classifier_service.dart';
import 'package:city_courierapp/services/maps/traffic_service.dart';

/// Membangun layer overlay TomTom Traffic untuk disisipkan DI ATAS OSM TileLayer
/// namun DI BAWAH garis rute dan marker kurir/tujuan agar tidak menghalangi.
List<Widget> buildTrafficOverlayLayers({
  required TrafficController controller,
  required TrafficService trafficService,
}) {
  if (!controller.isTrafficEnabled) return const [];

  final selectedRoad = controller.selectedRoad;
  final incidents = controller.incidents;

  return [
    if (controller.canRenderTrafficTiles)
      Opacity(
        opacity: 0.82,
        child: TileLayer(
          key: ValueKey('tomtom-traffic-${controller.tileEpoch}'),
          urlTemplate: trafficService.buildFlowTileUrl(
            epoch: controller.tileEpoch,
          ),
          tileProvider: NetworkTileProvider(
            headers: controller.tileHeaders,
            silenceExceptions: true,
          ),
          maxNativeZoom: 22,
          maxZoom: 22,
        ),
      ),
    if (incidents.any((i) => i.coordinates.length >= 2))
      PolylineLayer(
        polylines: [
          for (final inc in incidents)
            if (inc.coordinates.length >= 2)
              Polyline(
                points: inc.coordinates,
                strokeWidth: inc.category == 'road_closed' ? 6.5 : 5.0,
                color: inc.markerColor.withValues(alpha: 0.85),
              ),
        ],
      ),
    if (selectedRoad != null && selectedRoad.coordinates.length >= 2)
      PolylineLayer(
        polylines: [
          Polyline(
            points: selectedRoad.coordinates,
            strokeWidth: 9.0,
            color: Colors.white.withValues(alpha: 0.9),
          ),
          Polyline(
            points: selectedRoad.coordinates,
            strokeWidth: 5.5,
            color: selectedRoad.classification.color,
          ),
        ],
      ),
    if (incidents.isNotEmpty)
      MarkerLayer(
        markers: [
          for (final inc in incidents)
            Marker(
              point: inc.point,
              width: 34,
              height: 34,
              child: GestureDetector(
                onTap: () => controller.selectIncident(inc),
                child: Container(
                  decoration: BoxDecoration(
                    color: inc.markerColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(inc.iconData, color: Colors.white, size: 18),
                ),
              ),
            ),
        ],
      ),
  ];
}

/// A. Traffic Layer Toggle button.
class TrafficLayerToggleChip extends StatelessWidget {
  final TrafficController controller;
  final bool compact;

  const TrafficLayerToggleChip({
    super.key,
    required this.controller,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final active = controller.isTrafficEnabled;
    final hasError = active && controller.errorMessage != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: controller.toggleTraffic,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 12,
            vertical: compact ? 6 : 8,
          ),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: hasError
                  ? TrafficClassifierService.congestedColor
                  : (active
                        ? AppColors.primaryOrange
                        : const Color(0xFFE2E8F0)),
              width: 1.3,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (controller.isLoading && active)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primaryOrange,
                  ),
                )
              else
                Icon(
                  Icons.traffic_rounded,
                  size: compact ? 15 : 17,
                  color: active ? AppColors.primaryOrange : Colors.black87,
                ),
              const SizedBox(width: 6),
              Text(
                active ? 'Lalu Lintas ON' : 'Lalu Lintas',
                style: AppTypography.caption.copyWith(
                  fontSize: compact ? 11 : 12,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : Colors.black87,
                ),
              ),
              if (active && controller.incidents.isNotEmpty) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: TrafficClassifierService.congestedColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${controller.incidents.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// B. Traffic Legend: Hijau (Lancar), Kuning (Mulai padat), Oranye (Padat), Merah (Macet).
class TrafficLegendPill extends StatelessWidget {
  final VoidCallback? onRefreshTap;
  final bool isLoading;

  const TrafficLegendPill({
    super.key,
    this.onRefreshTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _dotItem('Lancar', TrafficClassifierService.smoothColor),
          _dotItem('Mulai padat', TrafficClassifierService.moderateColor),
          _dotItem('Padat', TrafficClassifierService.heavyColor),
          _dotItem('Macet', TrafficClassifierService.congestedColor),
          if (onRefreshTap != null)
            GestureDetector(
              onTap: isLoading ? null : onRefreshTap,
              child: Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Icon(
                  Icons.refresh_rounded,
                  size: 15,
                  color: isLoading ? Colors.grey : AppColors.primaryOrange,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _dotItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }
}

/// E. Loading / Error / Offline / Stale indicator.
class TrafficStatusBanner extends StatelessWidget {
  final TrafficController controller;

  const TrafficStatusBanner({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    if (!controller.isTrafficEnabled) return const SizedBox.shrink();

    final err = controller.errorMessage;
    final expired = controller.isDataExpired;
    if (!controller.isLoading && err == null && !expired) {
      return const SizedBox.shrink();
    }

    final isOfflineOrErr = err != null || expired;
    final bg = err != null
        ? const Color(0xFFFEF2F2)
        : (expired ? const Color(0xFFFFFBEB) : Colors.white);
    final border = err != null
        ? const Color(0xFFFECACA)
        : (expired ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0));
    final fg = err != null
        ? const Color(0xFF991B1B)
        : (expired ? const Color(0xFF92400E) : const Color(0xFF334155));
    final text = err ??
        (expired
            ? 'Data lalu lintas kedaluwarsa. Muat ulang untuk kondisi real-time.'
            : 'Memuat data lalu lintas TomTom...');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 5, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (controller.isLoading && !isOfflineOrErr)
            const SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primaryOrange,
              ),
            )
          else
            Icon(
              controller.errorKind == TrafficErrorKind.offline
                  ? Icons.wifi_off_rounded
                  : Icons.info_outline_rounded,
              size: 15,
              color: fg,
            ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ),
          if (isOfflineOrErr) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => controller.refreshNow(force: true),
              child: const Text(
                'Coba Lagi',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryOrange,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// C. Traffic Information Card (ketika kurir memilih / mengetuk ruas jalan).
class TrafficRoadInfoCard extends StatelessWidget {
  final TrafficFlowSegment segment;
  final VoidCallback onClose;

  const TrafficRoadInfoCard({
    super.key,
    required this.segment,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final cls = segment.classification;
    final updatedLocal = segment.fetchedAt.toLocal();
    final updatedStr = DateFormat('HH:mm:ss').format(updatedLocal);
    final ageSec = DateTime.now().difference(updatedLocal).inSeconds.clamp(0, 9999);
    final roadTitle = segment.roadName?.isNotEmpty == true
        ? segment.roadName!
        : 'Ruas Jalan (${segment.point.latitude.toStringAsFixed(4)}, ${segment.point.longitude.toStringAsFixed(4)})';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cls.color.withValues(alpha: 0.45), width: 1.4),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: cls.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: cls.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      cls.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: cls.color,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  roadTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              GestureDetector(
                onTap: onClose,
                child: const Icon(Icons.close_rounded, size: 18, color: Colors.black54),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _metricTile(
                'Kecepatan Aktual',
                segment.currentSpeedKmh != null
                    ? '${segment.currentSpeedKmh} km/jam'
                    : 'Tidak tersedia',
              ),
              const SizedBox(width: 8),
              _metricTile(
                'Bebas Hambatan',
                segment.freeFlowSpeedKmh != null
                    ? '${segment.freeFlowSpeedKmh} km/jam'
                    : 'Tidak tersedia',
              ),
              const SizedBox(width: 8),
              _metricTile(
                'Kepadatan',
                cls.congestionPercent != null
                    ? '${cls.congestionPercent!.toStringAsFixed(0)}%'
                    : '-',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Pembaruan: $updatedStr (${ageSec}d lalu)',
                style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
              ),
              if (segment.isExpired)
                const Text(
                  'Kedaluwarsa',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: TrafficClassifierService.congestedColor,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricTile(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 9.5,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// D. Traffic Incident detail card ketika kurir mengetuk marker insiden.
class TrafficIncidentInfoCard extends StatelessWidget {
  final TrafficIncident incident;
  final VoidCallback onClose;

  const TrafficIncidentInfoCard({
    super.key,
    required this.incident,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final routeRange = [
      if (incident.from?.isNotEmpty == true) incident.from!,
      if (incident.to?.isNotEmpty == true) incident.to!,
    ].join(' → ');
    final delayMinutes = incident.delaySeconds != null && incident.delaySeconds! > 0
        ? '+${(incident.delaySeconds! / 60).ceil()} menit'
        : null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: incident.markerColor.withValues(alpha: 0.45), width: 1.4),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: incident.markerColor.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(incident.iconData, size: 17, color: incident.markerColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      incident.categoryLabel,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: incident.markerColor,
                      ),
                    ),
                    Text(
                      incident.severityLabel,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (delayMinutes != null)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    delayMinutes,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                ),
              GestureDetector(
                onTap: onClose,
                child: const Icon(Icons.close_rounded, size: 18, color: Colors.black54),
              ),
            ],
          ),
          if (routeRange.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              routeRange,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
          if (incident.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              incident.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569), height: 1.35),
            ),
          ],
        ],
      ),
    );
  }
}

/// Widget kondisi lalu lintas di halaman Detail Pengiriman Kurir (Pickup, Tujuan, Peringatan,
/// serta fondasi rute alternatif tanpa mengklaim fitur sudah aktif).
class TrafficDeliverySummaryCard extends StatelessWidget {
  final TrafficController controller;
  final VoidCallback onRetry;

  const TrafficDeliverySummaryCard({
    super.key,
    required this.controller,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final summary = controller.deliverySummary;
    final loading = controller.isLoadingSummary;
    final err = controller.summaryError;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (summary?.hasCongestion == true)
              ? TrafficClassifierService.heavyColor.withValues(alpha: 0.5)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.traffic_rounded, size: 17, color: Color(0xFFFF5A00)),
              const SizedBox(width: 7),
              const Expanded(
                child: Text(
                  'Kondisi Lalu Lintas Pengiriman',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              if (loading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF5A00)),
                )
              else
                GestureDetector(
                  onTap: onRetry,
                  child: const Icon(Icons.refresh_rounded, size: 17, color: Color(0xFFFF5A00)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (loading && summary == null)
            const Text(
              'Memeriksa arus lalu lintas di area penjemputan dan tujuan...',
              style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
            )
          else if (err != null && summary == null)
            Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 15, color: Color(0xFF64748B)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    err,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ),
              ],
            )
          else if (summary == null)
            const Text(
              'Data lalu lintas belum tersedia.',
              style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: _areaBox('Sekitar Penjemputan', summary.pickupTraffic),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _areaBox('Sekitar Tujuan', summary.dropoffTraffic),
                ),
              ],
            ),
            if (summary.warnings.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFED7AA)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.warning_amber_rounded, size: 15, color: Color(0xFFEA580C)),
                        SizedBox(width: 5),
                        Text(
                          'Peringatan Kemacetan',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF9A3412),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    for (final w in summary.warnings.take(3))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          '• ${w.title}${w.detail.isNotEmpty ? ' — ${w.detail}' : ''}',
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: Color(0xFF7C2D12),
                            height: 1.35,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              summary.alternativeRoute.message.isNotEmpty
                  ? summary.alternativeRoute.message
                  : 'Fondasi rekomendasi rute alternatif siap; routing aktif memakai OSRM OpenStreetMap.',
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF64748B),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _areaBox(String title, TrafficFlowSegment? seg) {
    final cls = seg?.classification;
    final color = cls?.color ?? TrafficClassifierService.unknownColor;
    final label = cls?.label ?? 'Belum tersedia';
    final speedInfo = (seg?.currentSpeedKmh != null && seg?.freeFlowSpeedKmh != null)
        ? '${seg!.currentSpeedKmh}/${seg.freeFlowSpeedKmh} km/j'
        : '-';
    final congStr = cls?.congestionPercent != null
        ? ' • Padat ${cls!.congestionPercent!.toStringAsFixed(0)}%'
        : '';

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '$speedInfo$congStr',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, color: Color(0xFF475569)),
          ),
        ],
      ),
    );
  }
}

/// Panel kontrol mengambang standar untuk layer lalu lintas di atas peta penuh
/// (Toggle + status loading/error + legenda warna).
class TrafficMapFloatingControls extends StatelessWidget {
  final TrafficController controller;
  final bool compact;

  const TrafficMapFloatingControls({
    super.key,
    required this.controller,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TrafficLayerToggleChip(controller: controller, compact: compact),
            if (controller.isTrafficEnabled)
              GestureDetector(
                onTap: controller.toggleLegend,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF334155)),
                      if (!compact) ...[
                        const SizedBox(width: 4),
                        const Text(
                          'Legenda',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            TrafficStatusBanner(controller: controller),
          ],
        ),
        if (controller.isTrafficEnabled && controller.showLegend) ...[
          const SizedBox(height: 6),
          TrafficLegendPill(
            isLoading: controller.isLoading,
            onRefreshTap: () => controller.refreshNow(force: true),
          ),
        ],
      ],
    );
  }
}

/// Kartu detail ruas jalan atau insiden terpilih yang muncul di atas peta.
class TrafficSelectionOverlay extends StatelessWidget {
  final TrafficController controller;

  const TrafficSelectionOverlay({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    if (!controller.isTrafficEnabled) return const SizedBox.shrink();

    final road = controller.selectedRoad;
    if (road != null) {
      return TrafficRoadInfoCard(
        segment: road,
        onClose: controller.clearSelection,
      );
    }

    final inc = controller.selectedIncident;
    if (inc != null) {
      return TrafficIncidentInfoCard(
        incident: inc,
        onClose: controller.clearSelection,
      );
    }

    return const SizedBox.shrink();
  }
}

/// Membangun layer polyline rute navigasi yang mempertahankan warna biru utama
/// pada bagian lancar/normal dan mewarnai HANYA sub-segmen `[startIndex..endIndex]`
/// yang terdeteksi padat/macet (kuning, oranye, merah) di dalam casing putih.
List<Polyline> buildTrafficColoredRoutePolylines({
  required List<LatLng> coordinates,
  required List<RouteTrafficSegment> segments,
  bool trafficEnabled = true,
  Color baseColor = AppColors.primaryBlue,
  double casingWidth = 10.0,
  double lineWidth = 6.5,
}) {
  if (coordinates.length < 2) return const [];

  final polylines = <Polyline>[
    Polyline(
      points: coordinates,
      strokeWidth: casingWidth,
      color: Colors.white.withValues(alpha: 0.9),
    ),
    Polyline(
      points: coordinates,
      strokeWidth: lineWidth,
      color: baseColor,
    ),
  ];

  if (!trafficEnabled || segments.isEmpty) {
    return polylines;
  }

  final highlighted = segments.where((s) => s.shouldHighlightOnRoute).toList()
    ..sort((a, b) => _severityOrder(a.classification.level)
        .compareTo(_severityOrder(b.classification.level)));

  final maxIdx = coordinates.length - 1;
  for (final seg in highlighted) {
    int s = seg.startIndex.clamp(0, maxIdx);
    int e = seg.endIndex.clamp(s, maxIdx);
    if (e == s) {
      if (e + 1 <= maxIdx) {
        e = e + 1;
      } else if (s > 0) {
        s = s - 1;
      } else {
        continue;
      }
    }

    final subPoints = coordinates.sublist(s, e + 1);
    if (subPoints.length < 2) continue;

    polylines.add(
      Polyline(
        points: subPoints,
        strokeWidth: lineWidth,
        color: seg.routeLineColor,
      ),
    );
  }

  return polylines;
}

int _severityOrder(TrafficConditionLevel level) {
  switch (level) {
    case TrafficConditionLevel.moderate:
      return 1;
    case TrafficConditionLevel.heavy:
      return 2;
    case TrafficConditionLevel.congested:
      return 3;
    case TrafficConditionLevel.roadClosed:
      return 4;
    case TrafficConditionLevel.smooth:
    case TrafficConditionLevel.unknown:
      return 0;
  }
}

/// Mengonversi opsi `TrafficAlternativeRoute` menjadi `RouteModel` siap navigasi.
RouteModel routeModelFromAlternative(TrafficAlternativeRoute alt) {
  return RouteModel(
    coordinates: alt.coordinates,
    distanceMeters: alt.distanceMeters,
    durationSeconds: alt.travelTimeSeconds.toDouble(),
    trafficDurationSeconds: alt.travelTimeSeconds.toDouble(),
    summary: alt.viaRoad,
    steps: alt.steps
        .map(
          (s) => RouteStep(
            instruction: s.instruction,
            maneuver: s.maneuverType,
            roadName: s.roadName.isNotEmpty ? s.roadName : null,
            distanceMeters: s.distanceMeters,
            durationSeconds: s.durationSeconds,
          ),
        )
        .toList(),
  );
}

/// Banner ringkas "Peringatan Kemacetan" yang menampilkan info kemacetan terdekat
/// pada jalur pengiriman aktif (nama jalan, jarak dari kurir, status, kecepatan aktual/normal, delay).
class RouteCongestionAlertCard extends StatelessWidget {
  final RouteCongestionAlert alert;
  final TrafficAlternativeRoute? fasterAlternative;
  final VoidCallback? onViewAlternativesTap;
  final VoidCallback? onDismiss;

  const RouteCongestionAlertCard({
    super.key,
    required this.alert,
    this.fasterAlternative,
    this.onViewAlternativesTap,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final bool isClosed = alert.level == TrafficConditionLevel.roadClosed;
    final String title =
        isClosed ? 'Penutupan Jalan di Jalur' : 'Peringatan Kemacetan';
    final String roadText =
        (alert.roadName != null && alert.roadName!.trim().isNotEmpty)
            ? alert.roadName!.trim()
            : 'Ruas jalan di jalur aktif';

    final speedParts = <String>[];
    if (alert.currentSpeedKmh != null && alert.freeFlowSpeedKmh != null) {
      speedParts.add(
        'Aktual ${alert.currentSpeedKmh} km/jam • Normal ${alert.freeFlowSpeedKmh} km/jam',
      );
    } else if (alert.description != null &&
        alert.description!.trim().isNotEmpty) {
      speedParts.add(alert.description!.trim());
    }

    final savedMinutes = fasterAlternative != null &&
            fasterAlternative!.timeSavedSeconds >= 60
        ? (fasterAlternative!.timeSavedSeconds / 60.0).round()
        : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: alert.color.withValues(alpha: 0.55),
          width: 1.3,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: alert.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$title • ${alert.formattedDistance}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: alert.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  alert.statusLabel,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: alert.color,
                  ),
                ),
              ),
              if (alert.formattedDelay != null) ...[
                const SizedBox(width: 5),
                Text(
                  alert.formattedDelay!,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ],
              if (onDismiss != null) ...[
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: onDismiss,
                  child: const Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: Colors.black45,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Jalan: $roadText',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
          ),
          if (speedParts.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              speedParts.first,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.5,
                color: Color(0xFF475569),
              ),
            ),
          ],
          if (onViewAlternativesTap != null) ...[
            const SizedBox(height: 6),
            GestureDetector(
              onTap: onViewAlternativesTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: savedMinutes != null
                      ? const Color(0xFFECFDF5)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: savedMinutes != null
                        ? const Color(0xFF10B981)
                        : const Color(0xFFCBD5E1),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.alt_route_rounded,
                      size: 14,
                      color: savedMinutes != null
                          ? const Color(0xFF047857)
                          : const Color(0xFF334155),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      savedMinutes != null
                          ? 'Lihat Rute Alternatif (Hemat ~$savedMinutes mnt)'
                          : 'Periksa Rute Alternatif',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: savedMinutes != null
                            ? const Color(0xFF047857)
                            : const Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Membuka bottom sheet perbandingan rute utama vs rute alternatif berbasis TomTom Traffic.
/// Rute baru hanya diterapkan setelah kurir menekan tombol konfirmasi secara eksplisit.
Future<void> showRouteAlternativesSheet({
  required BuildContext context,
  required TrafficController controller,
  required LatLng origin,
  required LatLng destination,
  required String currentRouteSignature,
  required ValueChanged<TrafficAlternativeRoute> onConfirmAlternative,
}) {
  if (controller.alternativesResult == null ||
      controller.alternativesResult!.isExpired) {
    controller.loadTrafficAlternatives(
      origin: origin,
      destination: destination,
    );
  }

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) {
      return AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final result = controller.alternativesResult;
          final loading = controller.isLoadingAlternatives;
          final err = controller.alternativesError;

          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.72,
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.alt_route_rounded,
                      color: Color(0xFF0F7B4A),
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Rute & Alternatif Lalu Lintas',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: loading
                          ? null
                          : () => controller.loadTrafficAlternatives(
                                origin: origin,
                                destination: destination,
                                force: true,
                              ),
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                    ),
                  ],
                ),
                const Text(
                  'Perbandingan estimasi waktu tempuh real-time TomTom. Pilih rute secara manual untuk mengganti jalur navigasi.',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 12),
                if (loading && result == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Color(0xFF0F7B4A)),
                          SizedBox(height: 10),
                          Text(
                            'Menganalisa rute alternatif berbasis kemacetan...',
                            style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (err != null && result == null)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Color(0xFFDC2626)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            err,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF991B1B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (result == null || result.routes.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        'Belum ada rute alternatif tersedia untuk jalur ini.',
                        style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: result.routes.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, idx) {
                        final opt = result.routes[idx];
                        final optSig =
                            TrafficService.buildRouteSignature(opt.coordinates);
                        final isCurrent = optSig == currentRouteSignature ||
                            (idx == 0 &&
                                result.routes.every(
                                  (r) =>
                                      TrafficService.buildRouteSignature(
                                        r.coordinates,
                                      ) !=
                                      currentRouteSignature,
                                ));
                        final mins = (opt.travelTimeSeconds / 60.0).ceil();
                        final km =
                            (opt.distanceMeters / 1000.0).toStringAsFixed(1);
                        final delayMin = (opt.trafficDelaySeconds ?? 0) >= 60
                            ? '+${((opt.trafficDelaySeconds ?? 0) / 60.0).ceil()} mnt macet'
                            : 'Arus lancar';
                        final savedMin = opt.timeSavedSeconds >= 60
                            ? (opt.timeSavedSeconds / 60.0).round()
                            : null;

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: opt.isRecommended
                                ? const Color(0xFFF0FDF4)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isCurrent
                                  ? AppColors.primaryBlue
                                  : (opt.isRecommended
                                        ? const Color(0xFF16A34A)
                                        : const Color(0xFFE2E8F0)),
                              width: (isCurrent || opt.isRecommended) ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      opt.viaRoad != null
                                          ? '${opt.label} • via ${opt.viaRoad}'
                                          : opt.label,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ),
                                  if (opt.isRecommended && savedMin != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF16A34A),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        'Hemat $savedMin mnt',
                                        style: const TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                    )
                                  else if (isCurrent)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryBlue,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Text(
                                        'Rute Aktif',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Text(
                                    '$mins menit',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F7B4A),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${km.replaceAll('.', ',')} km • $delayMin',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF475569),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: opt.overallColor,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        opt.overallStatusLabel,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: opt.overallColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (!isCurrent)
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF0F7B4A),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 8,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        elevation: 0,
                                      ),
                                      onPressed: () {
                                        Navigator.of(sheetCtx).pop();
                                        onConfirmAlternative(opt);
                                      },
                                      child: const Text(
                                        'Gunakan Rute Ini',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      );
    },
  );
}

