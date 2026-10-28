import 'package:flutter/foundation.dart';

class DaftarKurirData extends ChangeNotifier {
  String? area;
  String? vehicleType;
  String? name;
  String? nik;
  String? email;
  String? phone;
  String? address;
  String? city;
  String? vehicleBrand;
  String? vehicleYear;
  String? vehiclePlate;
  String? photoPath;
  String? idCardPath;
  String? licensePath;
  String? skckPath;
  String? token;

  void reset() {
    area = null;
    vehicleType = null;
    name = null;
    nik = null;
    email = null;
    phone = null;
    address = null;
    city = null;
    vehicleBrand = null;
    vehicleYear = null;
    vehiclePlate = null;
    photoPath = null;
    idCardPath = null;
    licensePath = null;
    skckPath = null;
    token = null;
    notifyListeners();
  }
}
