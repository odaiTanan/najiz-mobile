/// User-facing Arabic copy for errors (non-technical).
class AppErrorMessages {
  AppErrorMessages._();

  static const String noInternet = 'لا يوجد اتصال بالإنترنت';
  static const String requestTimeout = 'انتهت مهلة الاتصال. حاول مرة أخرى.';
  static const String connectionFailed = 'تعذر الاتصال بالخادم. حاول لاحقاً.';
  static const String unexpected = 'حدث خطأ غير متوقع. حاول مرة أخرى.';
  static const String serverUnavailable =
      'الخدمة غير متاحة مؤقتاً. حاول لاحقاً.';
  static const String notFound = 'المحتوى غير متوفر.';
  static const String unauthorized = 'انتهت الجلسة. يرجى تسجيل الدخول مرة أخرى.';
  static const String forbidden = 'لا يمكن تنفيذ هذا الإجراء.';
  static const String badRequest = 'تعذر تنفيذ الطلب. تحقق من البيانات.';
  static const String displayError =
      'حدث خطأ في العرض. أعد فتح الصفحة أو حاول لاحقاً.';
}
