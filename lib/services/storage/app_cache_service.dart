import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:city_courierapp/services/courier/courier_directory_service.dart';
import 'package:city_courierapp/services/provider_availability_service.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Ringkasan ukuran cache sementara aplikasi (file sementara disk + ImageCache).
class CacheSizeInfo {
  final int totalBytes;
  final int diskBytes;
  final int imageCacheBytes;
  final String formattedSize;

  const CacheSizeInfo({
    required this.totalBytes,
    required this.diskBytes,
    required this.imageCacheBytes,
    required this.formattedSize,
  });
}

/// Hasil eksekusi pembersihan cache sementara aplikasi.
class CacheClearResult {
  final bool success;
  final int previousBytes;
  final int freedBytes;
  final int remainingBytes;
  final String formattedRemainingSize;
  final String? errorMessage;

  const CacheClearResult({
    required this.success,
    required this.previousBytes,
    required this.freedBytes,
    required this.remainingBytes,
    required this.formattedRemainingSize,
    this.errorMessage,
  });
}

/// Layanan pengelolaan cache sementara aplikasi City Courier.
///
/// Hanya membaca & menghapus direktori cache/sementara aplikasi,
/// Flutter `ImageCache`, serta cache transient di memori. Data autentikasi
/// (`TokenStore`), preferensi (`SharedPreferences`), pesanan aktif, saldo
/// City Wallet, riwayat transaksi, dan dokumen pengguna TIDAK pernah disentuh.
class AppCacheService {
  static final AppCacheService instance = AppCacheService();

  final Future<List<Directory>> Function()? _directoriesProvider;
  final ImageCache? Function()? _imageCacheProvider;
  final Future<void> Function(FileSystemEntity entity)? _deleteEntity;
  final void Function()? _clearExtraCaches;

  AppCacheService({
    Future<List<Directory>> Function()? directoriesProvider,
    ImageCache? Function()? imageCacheProvider,
    Future<void> Function(FileSystemEntity entity)? deleteEntity,
    void Function()? clearExtraCaches,
  })  : _directoriesProvider = directoriesProvider,
        _imageCacheProvider = imageCacheProvider,
        _deleteEntity = deleteEntity,
        _clearExtraCaches = clearExtraCaches;

  /// Mengukur estimasi ukuran cache sementara saat ini tanpa memblokir UI.
  Future<CacheSizeInfo> inspectCache({bool silentOnError = true}) async {
    int diskBytes = 0;
    try {
      final dirs = await _resolveCacheDirectories();
      final paths = dirs.map((d) => d.path).toList();
      if (paths.isNotEmpty) {
        diskBytes = await Isolate.run(() => _computeDirectoriesSizeSync(paths));
      }
    } catch (_) {
      if (!silentOnError) rethrow;
    }

    final imageCache = _getImageCache();
    final int imageCacheBytes = imageCache?.currentSizeBytes ?? 0;
    final int totalBytes = diskBytes + imageCacheBytes;

    return CacheSizeInfo(
      totalBytes: totalBytes,
      diskBytes: diskBytes,
      imageCacheBytes: imageCacheBytes,
      formattedSize: formatBytes(totalBytes),
    );
  }

  /// Menghapus file sementara aplikasi, `ImageCache`, dan cache transient
  /// di memori sambil menjaga seluruh data akun, token, wallet, dan preferensi.
  Future<CacheClearResult> clearCache() async {
    final before = await inspectCache(silentOnError: true);

    try {
      final dirs = await _resolveCacheDirectories();
      String? deletionError;

      if (_deleteEntity == null) {
        final paths = dirs.map((d) => d.path).toList();
        if (paths.isNotEmpty) {
          deletionError =
              await Isolate.run(() => _clearDirectoriesSync(paths));
        }
      } else {
        for (final dir in dirs) {
          if (!dir.existsSync()) continue;

          for (final entity in dir.listSync(followLinks: false)) {
            try {
              await _deleteEntity(entity);
            } catch (e) {
              if (entity.existsSync()) {
                deletionError ??= 'Sebagian file cache gagal dihapus: $e';
              }
            }
          }
        }
      }

      final imageCache = _getImageCache();
      if (imageCache != null) {
        imageCache.clear();
        imageCache.clearLiveImages();
      }

      // Bersihkan cache transient yang aman dibuat ulang tanpa menyentuh sesi/data user.
      ProviderAvailabilityService.clearCache();
      CourierDirectoryService.clearCache();
      _clearExtraCaches?.call();

      final after = await inspectCache(silentOnError: true);
      final freedBytes = math.max(0, before.totalBytes - after.totalBytes);

      if (deletionError != null) {
        return CacheClearResult(
          success: false,
          previousBytes: before.totalBytes,
          freedBytes: freedBytes,
          remainingBytes: after.totalBytes,
          formattedRemainingSize: after.formattedSize,
          errorMessage: 'Proses pembersihan cache tidak selesai sepenuhnya.',
        );
      }

      return CacheClearResult(
        success: true,
        previousBytes: before.totalBytes,
        freedBytes: freedBytes,
        remainingBytes: after.totalBytes,
        formattedRemainingSize: after.formattedSize,
      );
    } catch (e) {
      final after = await inspectCache(silentOnError: true);
      return CacheClearResult(
        success: false,
        previousBytes: before.totalBytes,
        freedBytes: math.max(0, before.totalBytes - after.totalBytes),
        remainingBytes: after.totalBytes,
        formattedRemainingSize: after.formattedSize,
        errorMessage: 'Gagal membersihkan cache aplikasi. Silakan coba lagi.',
      );
    }
  }

  ImageCache? _getImageCache() {
    if (_imageCacheProvider != null) {
      return _imageCacheProvider();
    }
    try {
      return PaintingBinding.instance.imageCache;
    } catch (_) {
      return null;
    }
  }

  Future<List<Directory>> _resolveCacheDirectories() async {
    if (_directoriesProvider != null) {
      return _deduplicateDirectories(await _directoriesProvider());
    }

    final candidates = <Directory>[];
    final systemTempPath = _normalizePath(Directory.systemTemp.path);
    final isMobile = Platform.isAndroid || Platform.isIOS;

    try {
      final cacheDir = await getApplicationCacheDirectory();
      candidates.add(cacheDir);
    } on MissingPluginException {
      // Abaikan jika plugin path_provider tidak tersedia di test tanpa mock.
    } on UnsupportedError {
      // Abaikan jika platform tidak mendukung direktori ini.
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final normalizedTemp = _normalizePath(tempDir.path);
      // Pada desktop non-sandbox, hindari membersihkan folder Temp global OS.
      if (isMobile || normalizedTemp != systemTempPath) {
        candidates.add(tempDir);
      }
    } on MissingPluginException {
      // Abaikan jika plugin path_provider tidak tersedia di test tanpa mock.
    } on UnsupportedError {
      // Abaikan jika platform tidak mendukung direktori ini.
    }

    return _deduplicateDirectories(candidates);
  }

  List<Directory> _deduplicateDirectories(List<Directory> dirs) {
    final seen = <String>{};
    final result = <Directory>[];
    for (final dir in dirs) {
      final key = _normalizePath(dir.path);
      if (seen.add(key)) {
        result.add(dir);
      }
    }
    return result;
  }

  String _normalizePath(String path) {
    return p.normalize(File(path).absolute.path);
  }

  static int _computeDirectoriesSizeSync(List<String> paths) {
    int total = 0;
    for (final path in paths) {
      final dir = Directory(path);
      if (!dir.existsSync()) continue;
      try {
        for (final entity in dir.listSync(recursive: true, followLinks: false)) {
          if (entity is File) {
            try {
              total += entity.lengthSync();
            } on FileSystemException {
              // File mungkin baru saja dihapus oleh proses lain.
            }
          }
        }
      } on FileSystemException {
        // Direktori cache tidak dapat diakses atau berubah di tengah pembacaan.
      }
    }
    return total;
  }

  static String? _clearDirectoriesSync(List<String> paths) {
    String? deletionError;
    for (final path in paths) {
      final dir = Directory(path);
      if (!dir.existsSync()) continue;
      try {
        for (final entity in dir.listSync(followLinks: false)) {
          try {
            entity.deleteSync(recursive: true);
          } catch (e) {
            if (entity.existsSync()) {
              deletionError ??= 'Sebagian file cache gagal dihapus: $e';
            }
          }
        }
      } catch (e) {
        deletionError ??= 'Gagal membaca direktori cache: $e';
      }
    }
    return deletionError;
  }

  /// Format byte menjadi string ukuran ringkas yang mudah dibaca pengguna.
  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';

    final double kb = bytes / 1024;
    if (kb < 1024) {
      return '${_trimZero(kb.toStringAsFixed(kb >= 10 ? 0 : 1))} KB';
    }

    final double mb = kb / 1024;
    if (mb < 1024) {
      return '${_trimZero(mb.toStringAsFixed(mb >= 10 ? 0 : 1))} MB';
    }

    final double gb = mb / 1024;
    return '${_trimZero(gb.toStringAsFixed(2))} GB';
  }

  static String _trimZero(String raw) {
    if (raw.contains('.')) {
      return raw.replaceAll(RegExp(r'\.?0+$'), '');
    }
    return raw;
  }
}
