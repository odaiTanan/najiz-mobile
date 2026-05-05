import 'package:get/get.dart';

/// يغطي التطبيق بالكامل بشاشة عدم الاتصال ويعيد المحاولة عبر [open].
class NoInternetGateController extends GetxController {
  final active = false.obs;
  Future<void> Function()? _userRetry;

  void open(Future<void> Function() userRetry) {
    _userRetry = userRetry;
    active.value = true;
  }

  void dismiss() {
    active.value = false;
    _userRetry = null;
  }

  Future<void> invokeUserRetry() async {
    final r = _userRetry;
    if (r == null) return;
    await r();
  }
}
