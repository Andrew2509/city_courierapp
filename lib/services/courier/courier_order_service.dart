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
    return getAvailableOrders();
  }

  static Future<Map<String, dynamic>> updateOrderStatus({
    required String orderId,
    required String status,
    String? photoPath,
    double? latitude,
    double? longitude,
    String? notes,
    String? issueReason,
    String? issueNotes,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/update-status-order');
      final request = http.MultipartRequest('POST', uri);
      
      request.fields['_method'] = 'PATCH'; 
      request.headers.addAll(await _getHeaders());
      request.fields['order_id'] = orderId;
      request.fields['status'] = status;

      if (latitude != null) request.fields['latitude'] = latitude.toString();
      if (longitude != null) request.fields['longitude'] = longitude.toString();
      if (notes != null) request.fields['notes'] = notes;
      if (issueReason != null) request.fields['issue_reason'] = issueReason;
      if (issueNotes != null) request.fields['issue_notes'] = issueNotes;

      if (photoPath != null && photoPath.isNotEmpty) {
        request.files.add(await http.MultipartFile.fromPath('photo', photoPath));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final responseData = json.decode(response.body);

      return {
        'success': response.statusCode == 200 && responseData['success'] == true,
        'message': responseData['message'] ?? (response.statusCode == 200 ? 'Sukses' : 'Gagal'),
        'data': responseData['data'],
        'statusCode': response.statusCode,
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> reportPickupIssue({
    required String orderId,
    required String reason,
    String? notes,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/orders/report-issue'),
        headers: await _getHeaders(),
        body: json.encode({
          'order_id': orderId,
          'issue_reason': reason,
          'issue_notes': notes,
          if (latitude != null) 'latitude': latitude,
          if (longitude != null) 'longitude': longitude,
        }),
      );

      final responseData = json.decode(response.body);
      return {
        'success': response.statusCode == 200 && responseData['success'] == true,
        'message': responseData['message'] ?? 'Laporan berhasil dicatat',
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
    return updateOrderStatus(
      orderId: requestId,
      status: 'cancelled',
      issueReason: 'courier_rejected',
      issueNotes: 'Kurir menolak penugasan',
    );
  }
}
