import 'package:city_courierapp/core/config/app_typography.dart';
import 'package:city_courierapp/services/storage/app_cache_service.dart';
import 'package:city_courierapp/widgets/common/city_courier_icon.dart';
import 'package:flutter/material.dart';

/// Dialog konfirmasi dan pemrosesan pembersihan cache aplikasi.
class ClearCacheDialog extends StatefulWidget {
  final AppCacheService cacheService;
  final String cacheSizeLabel;

  const ClearCacheDialog({
    super.key,
    required this.cacheService,
    required this.cacheSizeLabel,
  });

  static const Color primaryOrange = Color(0xFFFF5A00);

  /// Membuka dialog konfirmasi Bersihkan Cache dan mengembalikan hasil jika
  /// pengguna menekan tombol Bersihkan Cache, atau `null` jika dibatalkan.
  static Future<CacheClearResult?> show(
    BuildContext context, {
    required AppCacheService cacheService,
    required String cacheSizeLabel,
  }) {
    return showDialog<CacheClearResult>(
      context: context,
      barrierDismissible: true,
      builder: (_) => ClearCacheDialog(
        cacheService: cacheService,
        cacheSizeLabel: cacheSizeLabel,
      ),
    );
  }

  @override
  State<ClearCacheDialog> createState() => _ClearCacheDialogState();
}

class _ClearCacheDialogState extends State<ClearCacheDialog> {
  bool _isClearing = false;

  Future<void> _onConfirm() async {
    if (_isClearing) return;
    setState(() => _isClearing = true);

    final result = await widget.cacheService.clearCache();
    if (!mounted) return;
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color bodyColor =
        isDark ? Colors.grey.shade300 : const Color(0xFF475569);

    return PopScope(
      canPop: !_isClearing,
      child: AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: surfaceColor,
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
        actionsPadding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: ClearCacheDialog.primaryOrange.withValues(
                  alpha: isDark ? 0.2 : 0.12,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: CityCourierCustomIcon(
                  CourierIconKind.clearCache,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Bersihkan Cache?',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: titleColor,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0F172A)
                    : const Color(0xFFFFF5EE),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: ClearCacheDialog.primaryOrange.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  const CityCourierCustomIcon(
                    CourierIconKind.storageDisk,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Cache aplikasi saat ini: ${widget.cacheSizeLabel}.',
                      style: AppTypography.bodySmall.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Tindakan ini akan menghapus file sementara dan cache aplikasi untuk mengosongkan ruang penyimpanan tanpa menghapus akun atau data penting Anda.',
              style: AppTypography.bodyMedium.copyWith(
                fontSize: 13.5,
                height: 1.45,
                color: bodyColor,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _isClearing ? null : () => Navigator.of(context).pop(),
            child: Text(
              'Batal',
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: _isClearing ? null : _onConfirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: ClearCacheDialog.primaryOrange,
              foregroundColor: Colors.white,
              disabledBackgroundColor:
                  ClearCacheDialog.primaryOrange.withValues(alpha: 0.7),
              disabledForegroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
              textStyle: AppTypography.titleSmall.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
              ),
            ),
            child: _isClearing
                ? const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text('Membersihkan...'),
                    ],
                  )
                : const Text('Bersihkan Cache'),
          ),
        ],
      ),
    );
  }
}
