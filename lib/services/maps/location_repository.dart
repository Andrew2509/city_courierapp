import 'dart:async';
import 'package:flutter/foundation.dart';
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

  /// Search address with autocomplete-friendly provider strategy:
  ///
  /// 1. Check in-memory cache.
  /// 2. Primary: Photon (designed for search-as-you-type autocomplete with proximity bias).
  /// 3. Secondary: Backend API (caching proxy).
  /// 4. Fallback: Direct Nominatim (strictly as fallback to comply with OSM usage policy).
  Future<List<Address>> searchAddress(
    String query, {
    double? latitude,
    double? longitude,
    int limit = 5,
    int minResults = 1,
  }) async {
    final cleanQuery = query.toLowerCase().trim();
    if (cleanQuery.isEmpty) return [];

    final cacheKey =
        '${cleanQuery}_${latitude != null ? latitude.toStringAsFixed(3) : ""}_${longitude != null ? longitude.toStringAsFixed(3) : ""}';

    // Check in-memory cache first (PRD §37)
    final cached = _searchCache[cacheKey];
    if (cached != null && !cached.isExpired) {
      debugPrint('[LocationRepo] Cache hit for: $query');
      return cached.data;
    }

    List<Address> results = [];

    // 1️⃣ Primary: Photon (built for autocomplete search with proximity bias)
    try {
      debugPrint('[LocationRepo] Querying Photon autocomplete for: $query (lat: $latitude, lon: $longitude)');
      final photonResults = await _photon.searchAddress(
        query,
        latitude: latitude,
        longitude: longitude,
        limit: limit,
      );
      if (photonResults.isNotEmpty) {
        results = photonResults;
        debugPrint('[LocationRepo] Photon returned ${results.length} results');
        _searchCache[cacheKey] = _CacheEntry(results);
        return results;
      }
    } catch (e) {
      debugPrint('[LocationRepo] Photon failed: $e');
    }

    // 2️⃣ Secondary: Backend API proxy
    try {
      debugPrint('[LocationRepo] Trying backend API for: $query');
      final backendResults = await _backend.searchAddress(
        query,
        latitude: latitude,
        longitude: longitude,
        limit: limit,
      );
      debugPrint('[LocationRepo] Backend returned ${backendResults.length} results');
      if (backendResults.length >= minResults) {
        _searchCache[cacheKey] = _CacheEntry(backendResults);
        return backendResults;
      }
      if (backendResults.isNotEmpty) {
        results = backendResults;
      }
    } catch (e) {
      debugPrint('[LocationRepo] Backend failed: $e');
    }

    if (results.length >= minResults) {
      _searchCache[cacheKey] = _CacheEntry(results);
      return results;
    }

    // 3️⃣ Last Fallback: Direct Nominatim (only on failure/empty of primary providers)
    try {
      debugPrint('[LocationRepo] Trying Nominatim fallback for: $query');
      final nominatimResults = await _nominatim.searchAddress(
        query,
        latitude: latitude,
        longitude: longitude,
        limit: limit,
      );
      debugPrint('[LocationRepo] Nominatim returned ${nominatimResults.length} results');
      if (nominatimResults.isNotEmpty) {
        // Merge & deduplicate
        final merged = <Address>[...results, ...nominatimResults];
        final seen = <String>{};
        final unique = <Address>[];
        for (final addr in merged) {
          final key =
              '${addr.latitude.toStringAsFixed(4)},${addr.longitude.toStringAsFixed(4)}';
          if (seen.add(key)) {
            unique.add(addr);
          }
        }
        _searchCache[cacheKey] = _CacheEntry(unique);
        return unique;
      }
    } catch (e) {
      debugPrint('[LocationRepo] Nominatim fallback failed: $e');
    }

    if (results.isNotEmpty) {
      _searchCache[cacheKey] = _CacheEntry(results);
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
