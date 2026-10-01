import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:city_courierapp/services/api_service.dart';
import 'package:city_courierapp/services/token_store.dart';

class CourierOrderService {
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

  static Future<Map<String, dynamic>> _enrichOrderWithResi(Map<String, dynamic> order) async {
    final Map<String, dynamic> enriched = Map<String, dynamic>.from(order);
    final trackingNumber = enriched['tracking_number'];
    final orderNumber = enriched['order_number'] ?? enriched['shipment_number'];

    if ((trackingNumber == null || trackingNumber.toString().startsWith('SHP-')) && orderNumber != null) {
      try {
        final trackRes = await http.get(
          Uri.parse('$baseUrl/shipments/track/$orderNumber'),
          headers: await _getHeaders(),
        );
        if (trackRes.statusCode == 200) {
          final trackData = json.decode(trackRes.body);
          if (trackData['success'] == true && trackData['data'] != null) {
            final realResi = trackData['data']['tracking_number'];
            if (realResi != null && realResi.toString().isNotEmpty) {
              enriched['tracking_number'] = realResi;
            }
          }
        }
      } catch (_) {}
    }
    return enriched;
  }

  static Future<Map<String, dynamic>> getAvailableOrders() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/orders/available'),
        headers: await _getHeaders(),
      );

      final responseData = json.decode(response.body);
      if (response.statusCode == 200 && responseData['success'] == true) {
        final dynamic rawData = responseData['data'];
        final List<dynamic> ordersList = (rawData is Map && rawData.containsKey('data'))
            ? (rawData['data'] as List? ?? [])
            : (rawData is List ? rawData : []);

        final List<Map<String, dynamic>> enrichedOrders = [];
        for (var item in ordersList) {
          if (item is Map<String, dynamic>) {
            enrichedOrders.add(await _enrichOrderWithResi(item));
          } else {
            enrichedOrders.add(item);
          }
        }

        return {
          'success': true,
          'data': enrichedOrders,
        };
      }
      return {'success': false, 'message': responseData['message'] ?? 'Gagal mengambil data'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getActiveOrder() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/orders/active'),
        headers: await _getHeaders(),
      );

      final responseData = json.decode(response.body);
      if (response.statusCode == 200 && responseData['success'] == true) {
        if (responseData['data'] != null && responseData['data'] is Map<String, dynamic>) {
          final enriched = await _enrichOrderWithResi(responseData['data']);
          return {
            'success': true,
            'data': enriched,
          };
        }
        return {
          'success': true,
          'data': responseData['data'],
        };
      }
      return {'success': false, 'message': responseData['message'] ?? 'Gagal mengambil data'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getOrdersByStatus(String status) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/orders?status=$status'),
        headers: await _getHeaders(),
      );

      final responseData = json.decode(response.body);
      if (response.statusCode == 200 && responseData['success'] == true) {
        final dynamic rawData = responseData['data'];
        final List<dynamic> ordersList = (rawData is Map && rawData.containsKey('data'))
            ? (rawData['data'] as List? ?? [])
            : (rawData is List ? rawData : []);

        final List<Map<String, dynamic>> enrichedOrders = [];
        for (var item in ordersList) {
          if (item is Map<String, dynamic>) {
            enrichedOrders.add(await _enrichOrderWithResi(item));
          } else {
            enrichedOrders.add(item);
          }
        }

        return {
          'success': true,
          'data': enrichedOrders,
        };
      }
      return {'success': false, 'message': responseData['message'] ?? 'Gagal mengambil data'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getPendingPickupRequests() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/orders/available'),
        headers: await _getHeaders(),
      );

      final responseData = json.decode(response.body);
      if (response.statusCode == 200 && responseData['success'] == true) {
        final dynamic rawData = responseData['data'];
        final List<dynamic> orders = (rawData is Map && rawData.containsKey('data'))
            ? (rawData['data'] as List? ?? [])
            : (rawData is List ? rawData : []);
        return {
          'success': true,
          'data': orders,
        };
      }
      return {'success': false, 'message': responseData['message'] ?? 'Gagal mengambil data'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> updateOrderStatus({
    required String orderId,
    required String status,
    String? photoPath,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/update-status-order');
      final request = http.MultipartRequest('POST', uri); // Use POST for Multipart
      
      // Laravel PATCH spoofing if needed, but OrderController is configured for POST/PATCH
      // We'll use PATCH if specified in api.php, but MultipartRequest is usually POST
      request.fields['_method'] = 'PATCH'; 
      
      request.headers.addAll(await _getHeaders());
      request.fields['order_id'] = orderId;
      request.fields['status'] = status;

      if (photoPath != null) {
        request.files.add(await http.MultipartFile.fromPath('photo', photoPath));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final responseData = json.decode(response.body);

      return {
        'success': response.statusCode == 200 && responseData['success'] == true,
        'message': responseData['message'] ?? (response.statusCode == 200 ? 'Sukses' : 'Gagal'),
        'data': responseData['data'],
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> acceptPickupRequest(String requestId) async {
    return updateOrderStatus(orderId: requestId, status: 'assigned');
  }

  static Future<Map<String, dynamic>> rejectPickupRequest(String requestId) async {
    // Current backend doesn't have a specific reject logic for couriers other than cancelled
    return updateOrderStatus(orderId: requestId, status: 'cancelled');
  }
}
