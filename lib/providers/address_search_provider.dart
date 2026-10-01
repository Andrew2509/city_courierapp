import 'package:flutter/foundation.dart';
import '../data/models/address_model.dart';
import '../services/maps/location_repository.dart';
import 'dart:async';
import '../core/config/map_config.dart';

class AddressSearchProvider extends ChangeNotifier {
  final LocationRepository _locationRepository;

  AddressSearchProvider({LocationRepository? locationRepository})
      : _locationRepository = locationRepository ?? LocationRepository();

  List<Address> _searchResults = [];
  List<Address> get searchResults => _searchResults;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Timer? _debounce;
  String _currentQuery = '';

  void searchAddress(String query, {bool forceUpdate = false}) {
    if (query == _currentQuery && !forceUpdate) return;
    _currentQuery = query;

    if (_debounce?.isActive ?? false) _debounce!.cancel();

    if (query.length < MapConfig.minSearchCharacters) {
      _searchResults = [];
      _errorMessage = null;
      notifyListeners();
      return;
    }

    _debounce = Timer(MapConfig.searchDebounceDuration, () async {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      try {
        _searchResults = await _locationRepository.searchAddress(query);

        if (_searchResults.isEmpty) {
          _errorMessage = 'Alamat tidak ditemukan';
        }
      } catch (e) {
        _searchResults = [];
        _errorMessage = 'Terjadi kesalahan. Silakan coba lagi.';
      } finally {
        _isLoading = false;
        notifyListeners();
      }
    });
  }

  void clearSearch() {
    _currentQuery = '';
    _searchResults = [];
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
