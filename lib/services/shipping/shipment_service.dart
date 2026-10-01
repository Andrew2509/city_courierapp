import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:city_courierapp/services/api_service.dart';
import 'package:city_courierapp/services/token_store.dart';
import 'package:city_courierapp/models/shipping/shipment_model.dart';

class ShipmentService {
  static String get baseUrl => ApiService.baseUrl;

  static Future<String?> _getToken() async => TokenStore.read();

  static Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Fetch user shipments, supporting comma-separated status values.
  /// If [status] contains commas (e.g. 'confirmed,assigned'), each status
  /// is fetched individually and results are merged + deduplicated.
  static Future<Map<String, dynamic>> getUserShipments({
    String? status,
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      // If multiple statuses are requested, fetch each separately and merge
      if (status != null && status.contains(',')) {
        final statuses = status.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
        final allShipments = <ShipmentModel>[];
        for (final s in statuses) {
          final result = await _fetchShipmentsForStatus(s, page: page, perPage: perPage);
          if (result['success'] == true) {
            allShipments.addAll(List<ShipmentModel>.from(result['data']));
          }
        }

        // Deduplicate by shipment id
        final Map<int, ShipmentModel> uniqueMap = {};
        for (final s in allShipments) {
          uniqueMap[s.id] = s;
        }

        return {
          'success': true,
          'data': uniqueMap.values.toList(),
        };
      }

      // Single status or all shipments
      return await _fetchShipmentsForStatus(
        status,
        page: page,
        perPage: perPage,
      );
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan sistem: $e', 'data': []};
    }
  }

  /// Internal: fetch shipments for a single status value.
  static Future<Map<String, dynamic>> _fetchShipmentsForStatus(
    String? status, {
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'per_page': perPage.toString(),
      };
      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }

      final queryString = Uri(queryParameters: queryParams).query;
      final uri = Uri.parse('$baseUrl/shipments?$queryString');

      final response = await http.get(
        uri,
        headers: await _getHeaders(),
      );

      final dynamic responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData is Map && responseData['success'] == true) {
        final List<ShipmentModel> shipmentsList = [];
        final data = responseData['data'];
        
        // Laravel Pagination returns data in data['data']
        final List shipmentsData = (data is Map && data.containsKey('data')) 
            ? data['data'] 
            : (data is List ? data : []);
        
        for (var item in shipmentsData) {
          if (item is Map<String, dynamic>) {
            shipmentsList.add(ShipmentModel.fromJson(item));
          }
        }

        return {
          'success': true,
          'data': shipmentsList,
        };
      }
      
      String message = 'Gagal mengambil data';
      if (responseData is Map && responseData.containsKey('message')) {
        message = responseData['message'];
      } else if (responseData is String) {
        message = responseData;
      }
      
      return {'success': false, 'message': message, 'data': []};
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan sistem: $e', 'data': []};
    }
  }

  static Future<Map<String, dynamic>> getShipment(int id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/shipments/$id'),
        headers: await _getHeaders(),
      );

      final responseData = json.decode(response.body);
      if (response.statusCode == 200 && responseData['success'] == true) {
        return {
          'success': true,
          'data': ShipmentModel.fromJson(responseData['data']),
        };
      }
      return {'success': false, 'message': responseData['message'] ?? 'Gagal mengambil data'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getShipmentStats() async {
    try {
      final headers = await _getHeaders();
      
      // Try the dedicated stats endpoint first
      final response = await http.get(
        Uri.parse('$baseUrl/shipments/stats'),
        headers: headers,
      );

      final dynamic responseData = json.decode(response.body);
      if (response.statusCode == 200 && responseData is Map && responseData['success'] == true) {
        return {
          'success': true,
          'data': responseData['data'],
        };
      }
      
      // Fallback: if stats endpoint is not available, compute from shipments list
      if (response.statusCode == 404 || (responseData is Map && responseData['success'] != true)) {
        return await _computeStatsFromShipments(headers);
      }
      
      String message = 'Gagal mengambil statistik';
      if (responseData is Map && responseData.containsKey('message')) {
        message = responseData['message'];
      } else if (responseData is String) {
        message = responseData;
      }
      
      return {'success': false, 'message': message};
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan statistik: $e'};
    }
  }

  /// Fallback: compute stats by fetching all shipments and counting by status.
  static Future<Map<String, dynamic>> _computeStatsFromShipments(
    Map<String, String> headers,
  ) async {
    try {
      final uri = Uri.parse('$baseUrl/shipments?per_page=200');
      final response = await http.get(uri, headers: headers);
      final dynamic responseData = json.decode(response.body);

      if (response.statusCode != 200 || responseData is! Map) {
        return {'success': false, 'message': 'Gagal mengambil data shipment'};
      }

      final data = responseData['data'];
      final List shipmentsData = (data is Map && data.containsKey('data'))
          ? data['data']
          : (data is List ? data : []);

      final stats = <String, int>{
        'pending': 0,
        'confirmed': 0,
        'assigned': 0,
        'picking_up': 0,
        'picked_up': 0,
        'delivering': 0,
        'in_transit': 0,
        'delivered': 0,
        'cancelled': 0,
      };

      for (var item in shipmentsData) {
        if (item is Map<String, dynamic>) {
          final status = (item['status'] ?? '').toString();
          if (stats.containsKey(status)) {
            stats[status] = stats[status]! + 1;
          }
        }
      }

      return {'success': true, 'data': stats};
    } catch (e) {
      return {'success': false, 'message': 'Gagal menghitung statistik: $e'};
    }
  }
}
