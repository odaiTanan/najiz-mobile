import 'package:get/get.dart';
import 'package:najiz_go_express/core/services/auth_guard_service.dart';
import 'package:najiz_go_express/features/favorites/views/favorites_screen.dart';
import 'package:najiz_go_express/features/home/views/home_screen.dart';
import 'package:najiz_go_express/features/orders/views/my_orders_screen.dart';
import 'package:najiz_go_express/features/profile/views/profile_screen.dart';
import 'package:najiz_go_express/features/search/views/search_screen.dart';

class MainBottomNav {
  MainBottomNav._();

  static Future<void> onTap({
    required int index,
    required int currentIndex,
    String? token,
  }) async {
    // currentIndex = -1 means "embedded/service" screen,
    // so Home must still navigate back to the main home page.
    if (index == currentIndex && currentIndex >= 0) return;

    switch (index) {
      case 0:
        Get.offAll(() => HomeScreen(token: token));
        break;
      case 1:
        await AuthGuardService.runOrRequestLogin(
          onAuthenticated: (authToken) async {
            Get.offAll(() => MyOrdersScreen(token: authToken));
          },
        );
        break;
      case 2:
        Get.offAll(() => const FavoritesScreen());
        break;
      case 3:
        Get.offAll(() => SearchScreen(token: token));
        break;
      case 4:
        Get.offAll(() => ProfileScreen(token: token));
        break;
    }
  }
}
