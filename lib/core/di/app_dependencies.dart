import 'package:najiz_go_express/core/di/network_dependencies.dart';
import 'package:najiz_go_express/core/peak_hour/services/peak_hour_dependencies.dart';
import 'package:najiz_go_express/features/auth/services/auth_dependencies.dart';
import 'package:najiz_go_express/features/favorites/services/favorites_dependencies.dart';
import 'package:najiz_go_express/features/home/services/home_dependencies.dart';
import 'package:najiz_go_express/features/orders/services/orders_dependencies.dart';
import 'package:najiz_go_express/features/profile/services/profile_dependencies.dart';
import 'package:najiz_go_express/features/restaurant/services/restaurant_dependencies.dart';
import 'package:najiz_go_express/features/search/services/search_dependencies.dart';
import 'package:najiz_go_express/features/shipping/services/shipping_dependencies.dart';
import 'package:najiz_go_express/features/support/services/support_dependencies.dart';
import 'package:najiz_go_express/features/taxi/services/taxi_dependencies.dart';

void registerAppDependencies() {
  registerNetworkDependencies();
  registerPeakHourDependencies();
  registerAuthDependencies();
  registerHomeDependencies();
  registerRestaurantDependencies();
  registerOrdersDependencies();
  registerProfileDependencies();
  registerSearchDependencies();
  registerShippingDependencies();
  registerSupportDependencies();
  registerTaxiDependencies();
  registerFavoritesDependencies();
}
