import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  SessionService._();

  static const _tokenKey = 'auth_token';
  static const _userNameKey = 'user_name';
  static const _userPhoneKey = 'user_phone';
  static const _userEmailKey = 'user_email';
  static const _userReferralCodeKey = 'user_referral_code';
  static const _userAddressKey = 'user_address';
  static const _userAvatarPathKey = 'user_avatar_path';
  static const _localeCodeKey = 'locale_code';
  static const _themeDarkKey = 'app_theme_dark';

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
    await prefs.remove(_userReferralCodeKey);
    await prefs.remove(_userAddressKey);
    await prefs.remove(_userAvatarPathKey);
  }

  static Future<void> saveUserIdentity({
    String? name,
    String? phone,
    String? email,
    String? referralCode,
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
    if (referralCode != null && referralCode.trim().isNotEmpty) {
      await prefs.setString(_userReferralCodeKey, referralCode.trim());
    }
  }

  static Future<Map<String, String?>> getUserIdentity() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'name': prefs.getString(_userNameKey),
      'phone': prefs.getString(_userPhoneKey),
      'email': prefs.getString(_userEmailKey),
      'referralCode': prefs.getString(_userReferralCodeKey),
      'address': prefs.getString(_userAddressKey),
      'avatarPath': prefs.getString(_userAvatarPathKey),
    };
  }

  static Future<void> saveAddress(String address) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userAddressKey, address.trim());
  }

  static Future<void> saveAvatarPath(String? path) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = path?.trim() ?? '';
    if (normalized.isEmpty) {
      await prefs.remove(_userAvatarPathKey);
      return;
    }
    await prefs.setString(_userAvatarPathKey, normalized);
  }

  static Future<void> saveLocaleCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeCodeKey, code.trim().toLowerCase());
  }

  static Future<String?> getLocaleCode() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_localeCodeKey)?.trim().toLowerCase();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  static Future<void> saveThemeModeDark(bool dark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeDarkKey, dark);
  }

  static Future<bool> isDarkThemePreferred() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_themeDarkKey) ?? false;
  }
}
