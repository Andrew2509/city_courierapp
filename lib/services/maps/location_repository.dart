import 'dart:async';
import '../../data/models/address_model.dart';
import '../../core/config/map_config.dart';
import 'geocoding_service.dart';
import 'backend_geocoding_service.dart';
import 'nominatim_geocoding_service.dart';
import 'photon_geocoding_service.dart';

/// Location repository implementing the provider strategy (PRD §43):
///
///   Flutter → LocationRepository → Backend API → Nominatim → Photon
///
/// UI never knows which provider is being used (PRD §43).
/// Backend handles geocoding proxy, caching, and fallback logic.
class LocationRepository {
  final GeocodingService _backend;
  final GeocodingService _nominatim;
  final GeocodingService _photon;

  // Simple in-memory cache (PRD §37)
  final Map<String, _CacheEntry<List<Address>>> _searchCache = {};
  final Map<String, _CacheEntry<Address?>> _reverseCache = {};

  LocationRepository({
    GeocodingService? backend,
    GeocodingService? nominatim,
    GeocodingService? photon,
  })  : _backend = backend ?? BackendGeocodingService(),
        _nominatim = nominatim ?? NominatimGeocodingService(),
        _photon = photon ?? PhotonGeocodingService();

  /// Search address with fallback: Backend → Nominatim → Photon (PRD §44).
  ///
  /// Primary: Backend API (handles Nominatim + Photon with server-side cache).
  /// Fallback: Direct Nominatim if backend is unreachable.
  /// Fallback: Direct Photon if Nominatim also fails.
  Future<List<Address>> searchAddress(
    String query, {
    int minResults = 1,
  }) async {
    // Check in-memory cache first (PRD §37)
    final cached = _searchCache[query.toLowerCase().trim()];
    if (cached != null && !cached.isExpired) {
      print('[LocationRepo] Cache hit for: $query');
      return cached.data;
    }

    // 1️⃣ Try backend API (server-side Nominatim → Photon + cache)
    List<Address> results = [];
    try {
      print('[LocationRepo] Trying backend API for: $query');
      results = await _backend.searchAddress(query);
      print('[LocationRepo] Backend returned ${results.length} results');
      if (results.length >= minResults) {
        _searchCache[query.toLowerCase().trim()] = _CacheEntry(results);
        return results;
      }
    } catch (e) {
      print('[LocationRepo] Backend failed: $e');
    }

    // 2️⃣ Fallback: Direct Nominatim
    try {
      print('[LocationRepo] Trying direct Nominatim for: $query');
      final nominatimResults = await _nominatim.searchAddress(query);
      print('[LocationRepo] Nominatim returned ${nominatimResults.length} results');
      if (nominatimResults.isNotEmpty) {
        results = nominatimResults;
      }
    } catch (e) {
      print('[LocationRepo] Nominatim failed: $e');
    }

    if (results.length >= minResults) {
      _searchCache[query.toLowerCase().trim()] = _CacheEntry(results);
      return results;
    }

    // 3️⃣ Fallback: Direct Photon
    try {
      print('[LocationRepo] Trying Photon for: $query');
      final photonResults = await _photon.searchAddress(query);
      print('[LocationRepo] Photon returned ${photonResults.length} results');
      if (photonResults.isNotEmpty) {
        // Merge: prefer existing results, supplement with Photon
        final merged = <Address>[...results, ...photonResults];
        // Deduplicate by coordinates
        final seen = <String>{};
        final unique = <Address>[];
        for (final addr in merged) {
          final key =
              '${addr.latitude.toStringAsFixed(5)},${addr.longitude.toStringAsFixed(5)}';
          if (seen.add(key)) {
            unique.add(addr);
          }
        }
        _searchCache[query.toLowerCase().trim()] = _CacheEntry(unique);
        return unique;
      }
    } catch (e) {
      print('[LocationRepo] Photon failed: $e');
    }

    // Return whatever we have (possibly empty)
    print('[LocationRepo] All providers returned 0 results for: $query');
    if (results.isNotEmpty) {
      _searchCache[query.toLowerCase().trim()] = _CacheEntry(results);
    }
    return results;
  }

  /// Reverse geocode: lat/lng → address (PRD §17).
  ///
  /// Tries backend first, then Nominatim, then Photon.
  Future<Address?> reverseGeocode(double lat, double lng) async {
    // Check cache
    final key = '${lat.toStringAsFixed(5)},${lng.toStringAsFixed(5)}';
    final cached = _reverseCache[key];
    if (cached != null && !cached.isExpired) {
      return cached.data;
    }

    // 1️⃣ Try backend API
    Address? result;
    try {
      result = await _backend.reverseGeocode(lat, lng);
    } catch (_) {
      // Backend unreachable
    }

    if (result != null) {
      _reverseCache[key] = _CacheEntry(result);
      return result;
    }

    // 2️⃣ Fallback: Direct Nominatim reverse
    try {
      result = await _nominatim.reverseGeocode(lat, lng);
    } catch (_) {
      // Nominatim reverse failed
    }

    if (result != null) {
      _reverseCache[key] = _CacheEntry(result);
      return result;
    }

    // 3️⃣ Fallback: Direct Photon reverse
    try {
      result = await _photon.reverseGeocode(lat, lng);
    } catch (_) {
      // All providers failed
    }

    if (result != null) {
      _reverseCache[key] = _CacheEntry(result);
    }
    return result;
  }

  /// Clear expired cache entries.
  void cleanCache() {
    _searchCache.removeWhere((_, entry) => entry.isExpired);
    _reverseCache.removeWhere((_, entry) => entry.isExpired);
  }

  void dispose() {
    _searchCache.clear();
    _reverseCache.clear();
  }
}

/// Simple cache entry with TTL (PRD §37).
class _CacheEntry<T> {
  final T data;
  final DateTime createdAt;

  _CacheEntry(this.data) : createdAt = DateTime.now();

  bool get isExpired =>
      DateTime.now().difference(createdAt) > MapConfig.searchCacheTTL;
}
