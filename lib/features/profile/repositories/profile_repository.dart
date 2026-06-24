import 'package:najiz_go_express/core/di/network_dependencies.dart';
import 'package:najiz_go_express/core/network/api_error_mapper.dart';
import 'package:najiz_go_express/data/api/api_client.dart';
import 'package:najiz_go_express/features/profile/errors/profile_api_exception.dart';
import 'package:najiz_go_express/features/profile/models/referral_coupon_models.dart';
import 'package:najiz_go_express/features/profile/models/user_address.dart';
import 'package:najiz_go_express/features/profile/models/user_profile_model.dart';

class ProfileRepository {
  ProfileRepository({ApiClient? apiClient})
      : _api = apiClient ?? resolveApiClient();

  final ApiClient _api;

  Future<T> _run<T>(Future<T> Function() action) {
    return runWithMappedApiErrors(action, ProfileApiException.fromHome);
  }

  Future<UserProfileModel> getMe({
    required String token,
    Map<String, String?>? fallback,
  }) {
    return _run(() async {
      Object? lastError;
      for (final path in Endpoints.profileMeCandidates) {
        try {
          final data = await _api.getRaw(path: path, token: token);
          final map = ApiResponse.asMap(data);
          if (map.isEmpty) continue;
          return UserProfileModel.fromMeResponse(map, fallback: fallback);
        } catch (e) {
          lastError = e;
        }
      }
      if (lastError != null) throw lastError;
      throw const ProfileApiException('Profile load failed');
    });
  }

  Future<Map<String, dynamic>> addUserAddress({
    required String token,
    required Map<String, dynamic> payload,
  }) {
    return _run(
      () async {
        final result = await _api.postEnvelope(
          path: Endpoints.addressesCreate,
          token: token,
          body: payload,
        );
        _api.invalidateGetCache(pathPrefix: '/addresses/');
        return result;
      },
    );
  }

  Future<List<UserAddress>> getMyAddresses({
    required String token,
    bool forceRefresh = false,
  }) {
    return _run(() async {
      final data = await _api.getEnvelope(
        path: Endpoints.addressesMy,
        token: token,
        forceRefresh: forceRefresh,
      );
      return ApiResponse.asMapList(data['data'])
          .map(UserAddress.fromJson)
          .toList();
    });
  }

  Future<ReferralCodeInfo> getMyReferralCode({required String token}) {
    return _run(() async {
      final data = await _api.getRaw(
        path: Endpoints.referralsMyCode,
        token: token,
      );
      return ReferralCodeInfo.fromJson(ApiResponse.asMap(data));
    });
  }

  Future<List<ReferralItem>> getMyReferrals({required String token}) {
    return _run(() async {
      final data = await _api.getEnvelope(
        path: Endpoints.referralsMyReferrals,
        token: token,
      );
      return ApiResponse.asMapList(data['data'])
          .map(ReferralItem.fromJson)
          .toList();
    });
  }

  Future<List<UserCouponItem>> getMyCoupons({required String token}) {
    return _run(() async {
      final data = await _api.getEnvelope(
        path: Endpoints.couponsMy,
        token: token,
      );
      return ApiResponse.asMapList(data['data'])
          .map(UserCouponItem.fromJson)
          .toList();
    });
  }
}
