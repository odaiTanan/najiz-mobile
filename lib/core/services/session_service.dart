import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  SessionService._();

  static const _tokenKey = 'auth_token';
  static const _userNameKey = 'user_name';
  static const _userPhoneKey = 'user_phone';
  static const _userEmailKey = 'user_email';
  static const _userAddressKey = 'user_address';

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (token == null || token.trim().isEmpty) return null;
    return token;
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userNameKey);
    await prefs.remove(_userPhoneKey);
    await prefs.remove(_userEmailKey);
  }

  static Future<void> saveUserIdentity({
    String? name,
    String? phone,
    String? email,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (name != null && name.trim().isNotEmpty) {
      await prefs.setString(_userNameKey, name.trim());
    }
    if (phone != null && phone.trim().isNotEmpty) {
      await prefs.setString(_userPhoneKey, phone.trim());
    }
    if (email != null && email.trim().isNotEmpty) {
      await prefs.setString(_userEmailKey, email.trim());
    }
  }

  static Future<Map<String, String?>> getUserIdentity() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'name': prefs.getString(_userNameKey),
      'phone': prefs.getString(_userPhoneKey),
      'email': prefs.getString(_userEmailKey),
      'address': prefs.getString(_userAddressKey),
    };
  }

  static Future<void> saveAddress(String address) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userAddressKey, address.trim());
  }
}
