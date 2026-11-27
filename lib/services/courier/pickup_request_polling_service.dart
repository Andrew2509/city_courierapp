import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:city_courierapp/services/courier/courier_order_service.dart';
import 'package:city_courierapp/services/courier/courier_status_service.dart';
import 'package:city_courierapp/screens/courier/ci_word/shipment/driver_detail_shipment_screen.dart';

typedef ActiveOrderFetcher = Future<Map<String, dynamic>> Function();
typedef PendingOrdersFetcher = Future<Map<String, dynamic>> Function();
typedef OfferPresenter = Future<void> Function(Map<String, dynamic> requestData);

class PickupRequestPollingService {
  static PickupRequestPollingService? _instance;
  static PickupRequestPollingService get instance {
    _instance ??= PickupRequestPollingService._();
    return _instance!;
  }

  PickupRequestPollingService._();

  @visibleForTesting
  PickupRequestPollingService.forTesting({
    ActiveOrderFetcher? activeOrderFetcher,
    PendingOrdersFetcher? pendingOrdersFetcher,
    OfferPresenter? offerPresenter,
  })  : _activeOrderFetcher =
            activeOrderFetcher ?? CourierOrderService.getActiveOrder,
        _pendingOrdersFetcher =
            pendingOrdersFetcher ?? CourierOrderService.getPendingPickupRequests,
        _offerPresenter = offerPresenter;

  ActiveOrderFetcher _activeOrderFetcher = CourierOrderService.getActiveOrder;
  PendingOrdersFetcher _pendingOrdersFetcher =
      CourierOrderService.getPendingPickupRequests;
  OfferPresenter? _offerPresenter;

  Timer? _pollingTimer;
  bool _isPolling = false;
  bool _isShowingNotification = false;
  int _pollGeneration = 0;
  BuildContext? _context;
  CourierStatusService? _statusService;
  final Set<String> _shownRequestIds = {};
  Map<String, dynamic>? _currentOffer;

  static const int _pollingIntervalSeconds = 5;

  bool get isPolling => _isPolling;
  Map<String, dynamic>? get currentOffer => _currentOffer;

  void startPolling(
    BuildContext context, {
    CourierStatusService? statusService,
  }) {
    _context = context;
    _statusService ??= statusService ?? _tryResolveStatusService(context);
    _attachStatusListener();

    // Jangan mulai polling apabila kurir Offline, Busy/On Delivery, atau memiliki pesanan aktif.
    if (_statusService != null && !_statusService!.canReceiveNewOffers) {
      stopPolling(clearContext: false);
      return;
    }

    if (_isPolling) return;

    _isPolling = true;
    _pollGeneration++;
    _checkForNewRequests();

    _pollingTimer = Timer.periodic(
      const Duration(seconds: _pollingIntervalSeconds),
      (_) => _checkForNewRequests(),
    );
  }

  @visibleForTesting
  void startPollingForTest(
    CourierStatusService statusService, {
    bool triggerImmediatePoll = true,
  }) {
    _statusService = statusService;
    _attachStatusListener();
    if (!statusService.canReceiveNewOffers) {
      stopPolling(clearContext: false);
      return;
    }
    _isPolling = true;
    _pollGeneration++;
    if (triggerImmediatePoll) {
      _checkForNewRequests();
    }
  }

  void stopPolling({bool clearContext = true}) {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _isPolling = false;
    _pollGeneration++;
    clearPendingOffers();
    if (clearContext) {
      _detachStatusListener();
      _context = null;
      _statusService = null;
    }
  }

  /// Hapus cache penawaran saat kurir menjadi Offline atau Busy sehingga
  /// penawaran lama tidak tampil lagi.
  void clearPendingOffers() {
    _currentOffer = null;
  }

  CourierStatusService? _tryResolveStatusService(BuildContext context) {
    try {
      return Provider.of<CourierStatusService>(context, listen: false);
    } catch (_) {
      return null;
    }
  }

  void _attachStatusListener() {
    _statusService?.removeListener(_handleStatusChanged);
    _statusService?.addListener(_handleStatusChanged);
  }

  void _detachStatusListener() {
    _statusService?.removeListener(_handleStatusChanged);
  }

  void _handleStatusChanged() {
    final service = _statusService;
    if (service == null) return;
    if (!service.canReceiveNewOffers && _isPolling) {
      stopPolling(clearContext: false);
    }
  }

  @visibleForTesting
  Future<Map<String, dynamic>?> pollOnce() => _checkForNewRequests();

  Future<Map<String, dynamic>?> _checkForNewRequests() async {
    if (_isShowingNotification) return null;

    final int generation = _pollGeneration;
    final statusService = _statusService ??
        (_context != null ? _tryResolveStatusService(_context!) : null);

    // Dalam widget/UI mode (tanpa offerPresenter test), pastikan context masih mounted.
    if (_offerPresenter == null && (_context == null || !_context!.mounted)) {
      stopPolling();
      return null;
    }

    // 1. Tolak sebelum memanggil API apabila status bukan Online atau memiliki pesanan aktif.
    if (!_isPolling || statusService == null || !statusService.canReceiveNewOffers) {
      clearPendingOffers();
      return null;
    }

    try {
      // 2. Cek sumber kebenaran backend: apakah kurir memiliki pesanan aktif.
      final activeResult = await _activeOrderFetcher();
      if (generation != _pollGeneration ||
          !_isPolling ||
          !statusService.canReceiveNewOffers) {
        clearPendingOffers();
        return null;
      }

      if (activeResult['success'] == true && activeResult['data'] != null) {
        final activeMap = activeResult['data'] is Map<String, dynamic>
            ? activeResult['data'] as Map<String, dynamic>
            : null;
        if (activeMap != null) {
          statusService.syncFromActiveOrder(activeMap);
        }
        stopPolling(clearContext: false);
        return null;
      }

      // 3. Ambil penawaran pesanan tersedia hanya bila kurir benar-benar idle & Online.
      final result = await _pendingOrdersFetcher();

      // Re-validasi setelah async I/O selesai: jika selama request kurir berubah
      // ke Offline atau Busy/On Delivery, buang seluruh penawaran lama secara senyap.
      if (generation != _pollGeneration ||
          !_isPolling ||
          !statusService.canReceiveNewOffers) {
        clearPendingOffers();
        return null;
      }

      final meta = result['meta'];
      if (meta is Map && meta['eligible_for_orders'] == false) {
        clearPendingOffers();
        return null;
      }

      if (result['success'] == true && result['data'] != null) {
        final requests = result['data'] as List;

        final newRequests = requests.where((request) {
          if (request is! Map<String, dynamic>) return false;
          final status = request['status']?.toString().toLowerCase() ?? '';
          final isPending =
              status == 'pending' || status == 'broadcast' || status.isEmpty;
          final requestId = request['id'].toString();
          return isPending && !_shownRequestIds.contains(requestId);
        }).toList();

        if (newRequests.isNotEmpty) {
          final selectedRequest = newRequests.first as Map<String, dynamic>;
          _currentOffer = selectedRequest;
          await _showPickupNotification(selectedRequest, generation, statusService);
          return selectedRequest;
        }
      }
    } catch (e) {
      debugPrint('Error checking pickup requests: $e');
    }

    return null;
  }

  Future<void> _showPickupNotification(
    Map<String, dynamic> requestData,
    int generation,
    CourierStatusService statusService,
  ) async {
    // Penjaga akhir sebelum menampilkan notifikasi / layar penawaran baru.
    if (generation != _pollGeneration ||
        !_isPolling ||
        !statusService.canReceiveNewOffers) {
      clearPendingOffers();
      return;
    }

    final presenter = _offerPresenter;
    if (presenter != null) {
      _isShowingNotification = true;
      final requestId = requestData['id'].toString();
      _shownRequestIds.add(requestId);
      try {
        await presenter(requestData);
      } catch (_) {
        _shownRequestIds.remove(requestId);
      } finally {
        _isShowingNotification = false;
      }
      return;
    }

    if (_context == null || !_context!.mounted) return;

    _isShowingNotification = true;
    final requestId = requestData['id'].toString();
    _shownRequestIds.add(requestId);

    try {
      await Navigator.push(
        _context!,
        MaterialPageRoute(
          builder: (context) =>
              DriverDetailShipmentScreen(shipment: requestData),
        ),
      );
    } catch (e) {
      _shownRequestIds.remove(requestId);
    } finally {
      _isShowingNotification = false;
    }
  }
}
