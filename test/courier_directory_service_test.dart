import 'package:flutter_test/flutter_test.dart';
import 'package:city_courierapp/services/courier/courier_directory_service.dart';

void main() {
  group('CourierDirectoryInfo Tests', () {
    test('Correctly formats vehicleDescription with brand, model, and plate', () {
      const courier = CourierDirectoryInfo(
        id: 6,
        name: 'Princenton',
        vehicleBrand: 'honda',
        vehicleModel: 'Yamaha',
        vehiclePlate: 'B 1234 ABC',
        photo: 'couriers/photos/udQCz2SJPJZNlhuQpr4hIZVXu5E4AnSmxQsYqf7r.jpg',
      );

      expect(courier.vehicleDescription, 'honda Yamaha • B 1234 ABC');
    });

    test('Parses from JSON correctly', () {
      final json = {
        'id': 6,
        'name': 'Princenton',
        'photo': 'couriers/photos/udQCz2SJPJZNlhuQpr4hIZVXu5E4AnSmxQsYqf7r.jpg',
        'vehicle_type': 'motor',
        'vehicle_brand': 'honda',
        'vehicle_model': 'Yamaha',
        'vehicle_plate': 'B 1234 ABC',
      };

      final courier = CourierDirectoryInfo.fromJson(json);
      expect(courier.id, 6);
      expect(courier.name, 'Princenton');
      expect(courier.photo, 'couriers/photos/udQCz2SJPJZNlhuQpr4hIZVXu5E4AnSmxQsYqf7r.jpg');
      expect(courier.vehicleBrand, 'honda');
      expect(courier.vehicleModel, 'Yamaha');
      expect(courier.vehiclePlate, 'B 1234 ABC');
      expect(courier.vehicleDescription, 'honda Yamaha • B 1234 ABC');
    });
  });
}

