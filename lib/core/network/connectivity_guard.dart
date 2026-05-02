import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:najiz_go_express/core/constants/app_error_messages.dart';
import 'package:najiz_go_express/core/errors/home_api_exception.dart';

/// Blocks API calls when there is no working internet (avoids long timeouts).
class ConnectivityGuard {
  ConnectivityGuard._();

  static final InternetConnectionChecker _checker =
      InternetConnectionChecker.createInstance();

  static Future<bool> get hasConnection => _checker.hasConnection;

  /// Throws [HomeApiException] with a fixed Arabic message when offline.
  static Future<void> requireOnline() async {
    final ok = await _checker.hasConnection;
    if (!ok) {
      throw HomeApiException(AppErrorMessages.noInternet);
    }
  }
}
