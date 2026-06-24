import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:najiz_go_express/features/profile/errors/profile_api_exception.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/constants/app_colors.dart';
import 'package:najiz_go_express/features/profile/repositories/profile_repository.dart';
import 'package:najiz_go_express/features/profile/models/referral_coupon_models.dart';

class ReferralCouponScreen extends StatefulWidget {
  const ReferralCouponScreen({super.key, required this.token});

  final String token;

  @override
  State<ReferralCouponScreen> createState() => _ReferralCouponScreenState();
}

class _ReferralCouponScreenState extends State<ReferralCouponScreen> {
  final ProfileRepository _repository = ProfileRepository();

  bool _isLoading = true;
  String? _error;
  String _referralCode = '';
  List<ReferralItem> _referrals = const [];
  List<UserCouponItem> _coupons = const [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final code = await _repository.getMyReferralCode(token: widget.token);
      final referrals = await _repository.getMyReferrals(token: widget.token);
      final coupons = await _repository.getMyCoupons(token: widget.token);
      if (!mounted) return;
      setState(() {
        _referralCode = code.referralCode;
        _referrals = referrals;
        _coupons = coupons;
      });
    } on ProfileApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'referral.loadFailed'.tr);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _copyCode() async {
    if (_referralCode.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _referralCode));
    if (!mounted) return;
    final cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: cs.surface,
        content: Text(
          'referral.codeCopied'.tr,
          style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Text(
          'referral.title'.tr,
          style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w800),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_error!, style: const TextStyle(color: AppColors.error)),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cs.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: cs.outlineVariant),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'referral.codeLabel'.tr,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _referralCode.trim().isEmpty ? 'referral.codeUnavailable'.tr : _referralCode,
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.2,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: _copyCode,
                                    icon: const Icon(Icons.copy_rounded, color: AppColors.primary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'referral.referredUsers'.tr,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_referrals.isEmpty)
                        Text(
                          'referral.noReferrals'.tr,
                          style: const TextStyle(color: AppColors.textSecondary),
                        )
                      else
                        ..._referrals.map(
                          (item) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: cs.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: cs.outlineVariant),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: AppColors.primary.withValues(alpha: 0.14),
                                  child: Text(
                                    item.referredName.isEmpty
                                        ? '?'
                                        : item.referredName.characters.first,
                                    style: const TextStyle(color: AppColors.primary),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.referredName,
                                        style: const TextStyle(fontWeight: FontWeight.w700),
                                      ),
                                      Text(
                                        item.referredPhone,
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Text(
                        'referral.myCoupons'.tr,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_coupons.isEmpty)
                        Text(
                          'referral.noCoupons'.tr,
                          style: const TextStyle(color: AppColors.textSecondary),
                        )
                      else
                        ..._coupons.map(
                          (coupon) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: cs.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: cs.outlineVariant),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.local_offer_outlined, color: AppColors.primary),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        coupon.code,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: .5,
                                        ),
                                      ),
                                      Text(
                                        'referral.discountLabel'.trParams({'value': coupon.valueLabel}),
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: coupon.isActive
                                        ? const Color(0xFFE8F7EE)
                                        : const Color(0xFFF2F2F2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    coupon.isActive ? 'search.filterActive'.tr : 'search.filterInactive'.tr,
                                    style: TextStyle(
                                      color: coupon.isActive
                                          ? const Color(0xFF1B8E4B)
                                          : AppColors.textSecondary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}
