import 'dart:async';

import 'package:app_links/app_links.dart';

/// Mendengarkan deep link CityCourier (PRD §13, §32).
///
/// Setelah binding DANA selesai, backend me-redirect browser ke:
///   citycourier://dana/binding/success
///   citycourier://dana/binding/failed
///
/// Per PRD §13, deep link HANYA dipakai sebagai sinyal "kembali ke app";
/// status final harus selalu dikonfirmasi ke backend lewat GET /dana/status.
class DeepLinkService {
  DeepLinkService._internal();

  static final DeepLinkService instance = DeepLinkService._internal();

  final AppLinks _appLinks = AppLinks();
  final StreamController<Uri> _uriController =
      StreamController<Uri>.broadcast();

  StreamSubscription<Uri>? _subscription;

  Uri? _cachedInitial;
  bool _initialLoaded = false;

  /// Stream deep link yang masuk saat aplikasi sedang aktif (warm launch).
  Stream<Uri> get uriStream => _uriController.stream;

  /// Mulai mendengarkan deep link live (aplikasi aktif / dipanggil kembali).
  Future<void> init() async {
    if (_subscription != null) return;
    _subscription = _appLinks.uriLinkStream.listen(_uriController.add);
  }

  /// Ambil deep link cold start (aplikasi dibuka langsung dari link),
  /// dipanggil sekali. Digunakan router global di main.dart.
  Future<Uri?> getInitialLink() async {
    if (!_initialLoaded) {
      _initialLoaded = true;
      try {
        _cachedInitial = await _appLinks.getInitialLink();
      } catch (_) {
        _cachedInitial = null;
      }
    }
    return _cachedInitial;
  }

  bool isDanaSuccess(Uri uri) =>
      uri.scheme == 'citycourier' &&
      uri.host == 'dana' &&
      uri.path == '/binding/success';

  bool isDanaFailed(Uri uri) =>
      uri.scheme == 'citycourier' &&
      uri.host == 'dana' &&
      uri.path == '/binding/failed';

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}