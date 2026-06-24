class ApiConfig {
  ApiConfig._();

  static const String baseUrl = 'https://mobile.najizgo.com/api';

  /// GET / read operations.
  static const Duration readTimeout = Duration(seconds: 8);

  /// POST / PUT / PATCH / DELETE.
  static const Duration writeTimeout = Duration(seconds: 18);

  @Deprecated('Use readTimeout or writeTimeout')
  static const Duration timeout = readTimeout;
}

