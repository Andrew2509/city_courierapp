import 'package:flutter/material.dart';

import 'package:city_courierapp/core/config/app_colors.dart';
import 'package:city_courierapp/services/wallet/wallet_service.dart';

/// Bottom sheet notifikasi dompet.
///
/// Isinya diturunkan backend dari status transaksi sebenarnya
/// (GET /api/courier/wallet/notifications) — tidak ada notifikasi statis.
Future<void> showWalletNotifications(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _WalletNotificationsSheet(),
  );
}

class _WalletNotificationsSheet extends StatefulWidget {
  const _WalletNotificationsSheet();

  @override
  State<_WalletNotificationsSheet> createState() => _WalletNotificationsSheetState();
}

class _WalletNotificationsSheetState extends State<_WalletNotificationsSheet> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = WalletService.getNotifications();
  }

  void _reload() {
    setState(() {
      _future = WalletService.getNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Notifikasi',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF191B23),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh, size: 20, color: Color(0xFF64748B)),
                    tooltip: 'Muat ulang',
                  ),
                ],
              ),
            ),
            Flexible(
              child: FutureBuilder<Map<String, dynamic>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: CircularProgressIndicator(color: AppColors.primaryOrange),
                      ),
                    );
                  }

                  if (snapshot.data?['success'] != true) {
                    return _buildMessage(
                      icon: Icons.cloud_off,
                      title: 'Gagal memuat notifikasi',
                      subtitle: snapshot.data?['message']?.toString() ??
                          'Periksa koneksi internet Anda.',
                    );
                  }

                  final items = (snapshot.data?['items'] as List<WalletNotificationItem>?) ?? [];

                  if (items.isEmpty) {
                    return _buildMessage(
                      icon: Icons.notifications_none,
                      title: 'Belum ada notifikasi',
                      subtitle: 'Pemberitahuan penghubungan DANA dan status penarikan '
                          'akan muncul di sini.',
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    itemBuilder: (context, index) => _buildItem(items[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(WalletNotificationItem item) {
    final color = switch (item.level) {
      'success' => const Color(0xFF16A34A),
      'error' => const Color(0xFFDC2626),
      'warning' => const Color(0xFFD97706),
      _ => const Color(0xFF2563EB),
    };

    final icon = switch (item.level) {
      'success' => Icons.check_circle_outline,
      'error' => Icons.error_outline,
      'warning' => Icons.info_outline,
      _ => Icons.notifications_none,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF191B23),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.message,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: Color(0xFF64748B),
                  ),
                ),
                if (item.createdAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _relativeTime(item.createdAt!),
                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: const Color(0xFF94A3B8)),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF191B23),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.4),
          ),
        ],
      ),
    );
  }

  static String _relativeTime(DateTime value) {
    final diff = DateTime.now().difference(value);

    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';

    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return '${value.day} ${months[value.month - 1]} ${value.year}';
  }
}
