class ErrorMappers {
  /// Checks whether an API/controller error message likely represents
  /// "no internet / cannot reach the server".
  static bool isNoInternetErrorMessage(String? message) {
    if (message == null) return false;
    final m = message.toLowerCase();
    return m.contains('internet') ||
        m.contains('انترنت') ||
        m.contains('لا يوجد اتصال') ||
        m.contains('فشل الاتصال') ||
        m.contains('connection failed') ||
        m.contains('server timeout') ||
        m.contains('timeout') ||
        m.contains('مهلة') ||
        m.contains('انتهت مهلة') ||
        m.contains('تحقق من الإنترنت') ||
        m.contains('التحقق من الاتصال');
  }

  static String mapLoginErrorMessage(String rawMessage) {
    final m = rawMessage.toLowerCase();

    final looksLikePasswordIssue =
        m.contains('password') || m.contains('كلمة المرور');

    final looksLikeWrong =
        m.contains('incorrect') ||
        m.contains('wrong') ||
        m.contains('invalid') ||
        m.contains('credential') ||
        m.contains('credentials');

    if (looksLikePasswordIssue && looksLikeWrong) {
      return 'كلمة المرور خاطئة';
    }

    // Fallback: common phrasing.
    if (m.contains('invalid credentials') || m.contains('unauthorized')) {
      return 'كلمة المرور خاطئة';
    }

    return rawMessage;
  }

  static String mapSignupErrorMessage(String rawMessage) {
    final m = rawMessage.toLowerCase();

    final phoneSignals = m.contains('phone') || m.contains('رقم');
    final takenSignals = m.contains('taken') ||
        m.contains('already') ||
        m.contains('exists') ||
        m.contains('exist') ||
        m.contains('in use') ||
        m.contains('مستخدم');

    if (phoneSignals && takenSignals) {
      return 'لايمكنك انشاء حساب هذا الرقم مستخدم بالفعل اعد المحاولة برقم اخر جديد';
    }

    return rawMessage;
  }

  static String mapOtpErrorMessage(String rawMessage) {
    final m = rawMessage.toLowerCase();
    final looksWrong =
        m.contains('invalid') ||
        m.contains('incorrect') ||
        m.contains('wrong') ||
        m.contains('expired') ||
        m.contains('expired') ||
        m.contains('لا') ||
        m.contains('خطأ') ||
        m.contains('غير');

    final looksOtp = m.contains('otp') ||
        m.contains('code') ||
        m.contains('verification') ||
        m.contains('رمز') ||
        m.contains('تحقق');

    if (looksOtp && looksWrong) {
      return 'رمز التحقق خاطئ';
    }

    // Common API phrasing fallback.
    if (m.contains('رمز التحقق') && (m.contains('خاطئ') || m.contains('خطأ'))) {
      return 'رمز التحقق خاطئ';
    }

    return rawMessage;
  }
}

