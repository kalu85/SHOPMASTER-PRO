/// Input validation helpers (GSTIN, phone, email).
class Validators {
  Validators._();

  static final RegExp _gstin =
      RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$');
  static final RegExp _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final RegExp _phone = RegExp(r'^[0-9+\-\s]{8,15}$');

  static bool isValidGstin(String v) => _gstin.hasMatch(v.trim().toUpperCase());
  static bool isValidEmail(String v) => _email.hasMatch(v.trim());
  static bool isValidPhone(String v) => _phone.hasMatch(v.trim());
}
