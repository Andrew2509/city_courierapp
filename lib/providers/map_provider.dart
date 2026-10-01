import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../data/models/address_model.dart';
import '../data/models/route_model.dart';
import '../services/maps/routing_service.dart';
import '../services/maps/location_service.dart';
import '../core/config/map_config.dart';

enum NavigationState {
  INITIALIZING,
  LOADING_ROUTE,
  ROUTE_READY,
  NAVIGATING,
  OFF_ROUTE,
  REROUTING,
  ARRIVING,
  ARRIVED,
  COMPLETED,
  ERROR
}

class MapProvider extends ChangeNotifier {
  final RoutingService _routingService;
  final LocationService _locationService;

  MapProvider({
    RoutingService? routingService,
    LocationService? locationService,
  })  : _routingService = routingService ?? OSRMRoutingService(),
        _locationService = locationService ?? GeolocatorLocationService();

  NavigationState _navigationState = NavigationState.INITIALIZING;
  NavigationState get navigationState => _navigationState;

  RouteModel? _currentRoute;
  RouteModel? get currentRoute => _currentRoute;

  LatLng? _currentLocation;
  LatLng? get currentLocation => _currentLocation;

  Address? _pickupAddress;
  Address? get pickupAddress => _pickupAddress;

  Address? _deliveryAddress;
  Address? get deliveryAddress => _deliveryAddress;
  
  Address? _currentDestination;

  StreamSubscription<LatLng>? _locationSubscription;

  bool _isCourierMode = false;
  
  void setAddresses(Address pickup, Address delivery) {
    _pickupAddress = pickup;
    _deliveryAddress = delivery;
    _currentDestination = pickup; // Initial destination is pickup
    notifyListeners();
  }

  Future<void> startCourierNavigation() async {
    _isCourierMode = true;
    _navigationState = NavigationState.LOADING_ROUTE;
    notifyListeners();

    final gpsPos = await _locationService.getCurrentLocation();
    _currentLocation = gpsPos?.toLatLng();
    if (_currentLocation == null) {
      _navigationState = NavigationState.ERROR;
      notifyListeners();
      return;
    }

    await _calculateRouteToDestination();

    _locationSubscription = _locationService.startTracking().listen((LatLng newLocation) {
      _currentLocation = newLocation;
      _checkRouteProgress(newLocation);
      notifyListeners();
    });
  }

  Future<void> _calculateRouteToDestination() async {
    if (_currentLocation == null || _currentDestination == null) return;
    
    _navigationState = NavigationState.LOADING_ROUTE;
    notifyListeners();

    try {
      final destLatLng = LatLng(_currentDestination!.latitude, _currentDestination!.longitude);
      _currentRoute = await _routingService.calculateRoute(_currentLocation!, destLatLng);
      
      if (_currentRoute != null) {
        _navigationState = NavigationState.NAVIGATING;
      } else {
        _navigationState = NavigationState.ERROR;
      }
    } catch (e) {
      _navigationState = NavigationState.ERROR;
    }
    notifyListeners();
  }

  void _checkRouteProgress(LatLng newLocation) {
    if (_navigationState != NavigationState.NAVIGATING && 
        _navigationState != NavigationState.OFF_ROUTE) {
      return;
    }

    if (_currentRoute == null || _currentDestination == null) return;

    final destLatLng = LatLng(_currentDestination!.latitude, _currentDestination!.longitude);
    
    // 1. Check if arrived
    final distanceToDest = const Distance().as(LengthUnit.Meter, newLocation, destLatLng);
    if (distanceToDest <= MapConfig.arrivalRadiusMeters) {
      _navigationState = NavigationState.ARRIVING;
      // Note: As per PRD 51, don't automatically complete delivery.
      return;
    }

    // 2. Check if off-route
    if (_isOffRoute(newLocation, _currentRoute!.coordinates)) {
      _navigationState = NavigationState.OFF_ROUTE;
      _handleOffRoute();
    } else if (_navigationState == NavigationState.OFF_ROUTE) {
      // Back on route
      _navigationState = NavigationState.NAVIGATING;
    }
  }

  bool _isOffRoute(LatLng current, List<LatLng> path) {
    if (path.isEmpty) return false;
    
    double minDistance = double.infinity;
    const distance = Distance();

    for (int i = 0; i < path.length - 1; i++) {
      // Simplistic check for distance to line segment (could use more accurate math for real usage)
      double dist = distance.as(LengthUnit.Meter, current, path[i]);
      if (dist < minDistance) {
        minDistance = dist;
      }
    }

    return minDistance > MapConfig.offRouteThresholdMeters;
  }

  void _handleOffRoute() async {
    _navigationState = NavigationState.REROUTING;
    notifyListeners();
    await _calculateRouteToDestination();
  }

  // Called when courier picks up the package
  void markPackagePickedUp() {
    if (_deliveryAddress != null) {
      _currentDestination = _deliveryAddress;
      _calculateRouteToDestination(); // Recalculate route to recipient
    }
  }
  
  // Called when courier hands over the package
  void markDeliveryCompleted() {
    _navigationState = NavigationState.COMPLETED;
    _locationSubscription?.cancel();
    notifyListeners();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }
}
