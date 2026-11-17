/// Validasi yang dipakai bersama oleh formulir pendaftaran kurir.
class DaftarKurirValidators {
  static final RegExp _emailPattern = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');
  static final RegExp _digitsOnly = RegExp(r'^\d+$');

  static String? requiredText(String? value, String message) {
    if (value == null || value.trim().isEmpty) {
      return message;
    }
    return null;
  }

  static String? name(String? value) {
    return requiredText(value, 'Nama lengkap wajib diisi.');
  }

  static String? nik(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'NIK wajib diisi.';
    }
    if (text.length < 16) {
      return 'NIK harus terdiri dari 16 digit.';
    }
    if (text.length > 16) {
      return 'NIK maksimal 16 digit.';
    }
    if (!_digitsOnly.hasMatch(text)) {
      return 'NIK harus terdiri dari 16 digit.';
    }
    return null;
  }

  static String? birthPlace(String? value) {
    return requiredText(value, 'Tempat lahir wajib diisi.');
  }

  static String? birthDate(String? value) {
    return requiredText(value, 'Tanggal lahir wajib diisi.');
  }

  static String? gender(String? value) {
    if (value == null || value.isEmpty) {
      return 'Silakan pilih jenis kelamin.';
    }
    return null;
  }

  static String? email(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Alamat email wajib diisi.';
    }
    if (!_emailPattern.hasMatch(text)) {
      return 'Format email tidak valid.';
    }
    return null;
  }
}
