class MapConfig {
  // Provider settings
  static const String geocodingProvider = 'nominatim';
  static const String routingProvider = 'osrm';

  // API Endpoints — Nominatim
  // IMPORTANT: Replace with self-hosted instances for production.
  static const String nominatimBaseUrl = 'https://nominatim.openstreetmap.org';

  // API Endpoints — Photon (fallback geocoding)
  static const String photonBaseUrl = 'https://photon.komoot.io';

  // API Endpoints — OSRM (direct fallback routing)
  static const String osrmBaseUrl = 'https://router.project-osrm.org';

  // Off-route detection threshold (PRD §28)
  static const double offRouteThresholdMeters = 30.0;

  // Arrival radius (PRD §30)
  static const double arrivalRadiusMeters = 40.0;

  // Search settings
  static const int minSearchCharacters = 3;
  static const Duration searchDebounceDuration = Duration(milliseconds: 400);

  // GPS accuracy warning threshold (PRD §18)
  static const double gpsAccuracyWarningMeters = 80.0;

  // Reroute cooldown to avoid flooding API (PRD §36)
  static const Duration rerouteCooldown = Duration(seconds: 15);

  // Search cache TTL
  static const Duration searchCacheTTL = Duration(minutes: 5);

  // Network timeout
  static const Duration networkTimeout = Duration(seconds: 15);

  // App Default Location (Surabaya area)
  static const double defaultLatitude = -7.2575;
  static const double defaultLongitude = 112.7521;

  // Map default zoom
  static const double defaultZoom = 15.0;
  static const double searchResultZoom = 17.0;
  static const double navigationZoom = 16.0;
}
