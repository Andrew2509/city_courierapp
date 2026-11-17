import 'package:city_courierapp/models/security/account_security_models.dart';
import 'package:flutter/material.dart';

class SecurityDevicesScreen extends StatefulWidget {
  final List<TrustedDeviceSession> devices;
  final List<SecurityActivityLog> logs;
  final int initialTab; // 0 = Perangkat Tepercaya, 1 = Riwayat Aktivitas
  final Future<void> Function(TrustedDeviceSession device) onRemoveDevice;
  final VoidCallback onBack;

  const SecurityDevicesScreen({
    super.key,
    required this.devices,
    required this.logs,
    this.initialTab = 0,
    required this.onRemoveDevice,
    required this.onBack,
  });

  @override
  State<SecurityDevicesScreen> createState() => _SecurityDevicesScreenState();
}

class _SecurityDevicesScreenState extends State<SecurityDevicesScreen> {
  late int _tabIndex;
  int? _revokingId;

  @override
  void initState() {
    super.initState();
    _tabIndex = widget.initialTab;
  }

  @override
  void didUpdateWidget(covariant SecurityDevicesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      _tabIndex = widget.initialTab;
    }
  }

  Future<void> _confirmRemoveDevice(TrustedDeviceSession device) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Hapus Perangkat Tepercaya?',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Sesi login di "${device.deviceName}" akan langsung diakhiri dan perangkat tersebut harus login ulang.',
          style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE11D48),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Hapus Sesi'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _revokingId = device.id);
    try {
      await widget.onRemoveDevice(device);
    } finally {
      if (mounted) setState(() => _revokingId = null);
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
                  onPressed: widget.onBack,
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Color(0xFF1E293B),
                  ),
                ),
                Expanded(
                  child: Text(
                    _tabIndex == 0
                        ? 'Perangkat Tepercaya'
                        : 'Riwayat Aktivitas',
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
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _TabPill(
                    label: 'Perangkat Aktif (${widget.devices.length})',
                    selected: _tabIndex == 0,
                    onTap: () => setState(() => _tabIndex = 0),
                  ),
                  _TabPill(
                    label: 'Riwayat Keamanan',
                    selected: _tabIndex == 1,
                    onTap: () => setState(() => _tabIndex = 1),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _tabIndex == 0 ? _buildDevicesList() : _buildActivityLogs(),
          ),
        ],
      ),
    );
  }

  Widget _buildDevicesList() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Perangkat di bawah sedang memiliki sesi aktif pada akun City Courier Anda.',
          style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
        ),
        const SizedBox(height: 14),
        if (widget.devices.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(
              child: Text(
                'Belum ada daftar perangkat tersinkronisasi.',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
              ),
            ),
          ),
        ...widget.devices.map((device) {
          final isTablet = device.deviceType == 'tablet';
          final busy = _revokingId == device.id;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: device.isCurrent
                    ? const Color(0xFFFED7AA)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: device.isCurrent
                        ? const Color(0xFFFFF7ED)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isTablet
                        ? Icons.tablet_android_rounded
                        : Icons.smartphone_rounded,
                    color: device.isCurrent
                        ? const Color(0xFFEA580C)
                        : const Color(0xFF475569),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            device.deviceName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          if (device.isCurrent)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD1FAE5),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Sesi Ini',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF047857),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${device.locationLabel} • ${device.lastUsedLabel}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${device.platform} • ${device.appVersion}'
                        '${device.ipAddress != null ? " • IP ${device.ipAddress}" : ""}',
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!device.isCurrent) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: busy ? null : () => _confirmRemoveDevice(device),
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(0xFFFFF1F2),
                      foregroundColor: const Color(0xFFE11D48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                    child: busy
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Hapus',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildActivityLogs() {
    if (widget.logs.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Belum ada riwayat aktivitas keamanan tercatat.',
            style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: widget.logs.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        final log = widget.logs[index];
        final isAlert = log.status == 'alert';
        final isWarn = log.status == 'warning';
        final Color bg = isAlert
            ? const Color(0xFFFFF1F2)
            : (isWarn ? const Color(0xFFFFFBEB) : const Color(0xFFECFDF5));
        final Color fg = isAlert
            ? const Color(0xFFE11D48)
            : (isWarn ? const Color(0xFFD97706) : const Color(0xFF059669));

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isAlert
                      ? Icons.gpp_maybe_rounded
                      : (isWarn
                          ? Icons.shield_outlined
                          : Icons.verified_user_outlined),
                  color: fg,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      log.title,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    if (log.description != null &&
                        log.description!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        log.description!,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (log.deviceName != null) log.deviceName!,
                        if (log.ipAddress != null) 'IP ${log.ipAddress}',
                        if (log.timeLabel != null) log.timeLabel!,
                      ].join(' • '),
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TabPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: selected
                  ? const Color(0xFF1E293B)
                  : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }
}
