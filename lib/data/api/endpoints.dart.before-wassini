/// Central registry of all REST API paths (relative to [ApiConfig.baseUrl]).
class Endpoints {
  Endpoints._();

  // ── Auth ──────────────────────────────────────────────────────────────────
  static const authLogin = '/auth/login';
  static const authRegister = '/auth/register';
  static const authResendOtp = '/auth/resend-otp';
  static const authVerifyOtp = '/auth/verify-otp';
  static const authResetPassword = '/auth/reset-password';
  static const authForgotPassword = '/auth/forgot-password';
  static const authVerifyPasswordReset = '/auth/verify-password-reset';
  static const authDeleteAccount = '/auth/delete-account';

  static const userMe = '/user/me';

  /// Profile endpoints tried in order until one succeeds.
  static const profileMeCandidates = <String>[
    '/auth/me',
    userMe,
    '/user/profile',
    '/profile',
  ];

  /// @deprecated Use [profileMeCandidates].
  static const authProfileCandidates = profileMeCandidates;

  // ── Home / catalog ────────────────────────────────────────────────────────
  static const offers = '/offers';
  static const services = '/our-services';
  static const peakHourStatus = '/peak-hour-status';
  static String cmsPage(String slug) => '/pages/$slug';
  static const faq = '/pages/faq';
  static String serviceClassifications(int serviceId) =>
      '/services/$serviceId/classifications';
  static String classificationVendors(int classificationId) =>
      '/classifications/$classificationId/vendors';
  static String serviceVendors(int serviceId) => '/services/$serviceId/vendors';
  static String vendorProducts(int vendorId) => '/products/$vendorId';

  // ── Search ────────────────────────────────────────────────────────────────
  static const search = '/search';
  static const searchSuggestions = '/search/suggestions';
  static const searchTrending = '/search/trending';
  static const searchHistory = '/search/history';

  // ── Addresses ─────────────────────────────────────────────────────────────
  static const addressesCreate = '/addresses/create';
  static const addressesMy = '/addresses/my-addresses';

  // ── Orders ────────────────────────────────────────────────────────────────
  static const userOrders = '/user/orders';
  static const userOrdersCalculate = '/user/orders/calculate';
  static const userOrdersMy = '/user/orders/my';
  static const userOrdersUnavailabilityOptions =
      '/user/orders/unavailability-options';
  static String userOrder(int orderId) => '/user/orders/$orderId';
  static String userOrderDriver(int orderId) => '/user/orders/$orderId/driver';
  static String userOrderRate(int orderId) => '/user/orders/$orderId/rate';
  static String userOrderCancel(int orderId) => '/user/orders/$orderId/cancel';
  static String userOrderSos(int orderId) => '/user/orders/$orderId/sos';

  // ── Taxi ──────────────────────────────────────────────────────────────────
  static const taxiCalculatePrice = '/user/orders/taxi/calculate-price';
  static const taxiOrders = '/user/orders/taxi';

  // ── Shipping ──────────────────────────────────────────────────────────────
  static const shippingCalculate = '/user/orders/shipping/calculate';
  static const shippingOrders = '/user/orders/shipping';

  // ── Coupons & referrals ───────────────────────────────────────────────────
  static const couponsValidate = '/user/coupons/validate';
  static const couponsMy = '/user/coupons/my';
  static const referralsMyCode = '/user/referrals/my-code';
  static const referralsMyReferrals = '/user/referrals/my-referrals';

  // ── Favorites ─────────────────────────────────────────────────────────────
  static const favorites = '/favorites';
  static const favoritesToggle = '/favorites/toggle';
  static String favoriteItem(String type, int id) => '/favorites/$type/$id';

  // ── Support / chat ────────────────────────────────────────────────────────
  static const profile = '/profile';
  static const chatSupportConversation = '/chat/support-conversation';
  static String chatMessages(int conversationId) =>
      '/chat/messages/$conversationId';
  static String chatMessagesRead(int conversationId) =>
      '/chat/messages/$conversationId/read';

  // ── Push notifications (OneSignal) ────────────────────────────────────────
  static const onesignalSubscribe = '/onesignal/subscribe';
  static const onesignalUnsubscribe = '/onesignal/unsubscribe';
}
