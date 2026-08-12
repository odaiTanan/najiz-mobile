import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/constants/app_colors.dart';
import 'package:najiz_go_express/core/widgets/network_image_with_fallback.dart';
import 'package:najiz_go_express/features/home/models/offer_model.dart';

class HomeOfferSlider extends StatefulWidget {
  const HomeOfferSlider({
    super.key,
    required this.offers,
    required this.onTap,
  });

  final List<OfferModel> offers;
  final ValueChanged<OfferModel> onTap;

  @override
  State<HomeOfferSlider> createState() => _HomeOfferSliderState();
}

class _HomeOfferSliderState extends State<HomeOfferSlider> {
  static const _autoAdvanceInterval = Duration(seconds: 3);

  late final PageController _pageController;
  int _pageIndex = 0;
  Timer? _autoTimer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.88);
    WidgetsBinding.instance.addPostFrameCallback((_) => _restartAutoPlay());
  }

  @override
  void didUpdateWidget(covariant HomeOfferSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_effectivePageCount(oldWidget.offers) !=
            _effectivePageCount(widget.offers) ||
        oldWidget.offers.length != widget.offers.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _restartAutoPlay());
    }
  }

  int _effectivePageCount(List<OfferModel> offers) {
    if (offers.isEmpty) return 1;
    if (offers.length == 1) return 3;
    return offers.length;
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _restartAutoPlay() {
    _autoTimer?.cancel();
    if (_pageCount < 2) return;
    _autoTimer = Timer.periodic(_autoAdvanceInterval, (_) => _advanceOnePage());
  }

  void _advanceOnePage() {
    if (!mounted || !_pageController.hasClients || _pageCount < 2) return;
    final next = (_pageIndex + 1) % _pageCount;
    _pageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  int get _pageCount {
    if (widget.offers.isEmpty) return 1;
    if (widget.offers.length == 1) return 3;
    return widget.offers.length;
  }

  bool get _showPageDots => widget.offers.length > 1;

  OfferModel? _offerAt(int index) {
    if (widget.offers.isEmpty) return null;
    final i = widget.offers.length == 1 ? 0 : index;
    return widget.offers[i];
  }

  @override
  Widget build(BuildContext context) {
    if (widget.offers.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 186,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: PageView.builder(
              controller: _pageController,
              itemCount: _pageCount,
              onPageChanged: (i) => setState(() => _pageIndex = i),
              itemBuilder: (context, index) {
                final offer = _offerAt(index);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: _HomeOfferSlide(
                    offer: offer,
                    onTap: offer == null ? null : () => widget.onTap(offer),
                  ),
                );
              },
            ),
          ),
        ),
        if (_showPageDots) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.offers.length, (i) {
              final active = i == _pageIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 20 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.primary
                      : Theme.of(context)
                          .colorScheme
                          .outlineVariant
                          .withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.35),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

class _HomeOfferSlide extends StatelessWidget {
  const _HomeOfferSlide({
    required this.offer,
    this.onTap,
  });

  final OfferModel? offer;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final imageUrl = offer?.image?.trim();
    final title = (offer?.name ?? '').trim().isNotEmpty
        ? offer!.name.trim()
        : 'offers.limitedOffer'.tr;
    final subtitle = (offer?.vendor?.name ?? '').trim().isNotEmpty
        ? offer!.vendor!.name.trim()
        : 'offers.enjoyBestOffers'.tr;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          height: 186,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (imageUrl != null && imageUrl.isNotEmpty)
                  NetworkImageWithFallback(
                    url: imageUrl,
                    fit: BoxFit.cover,
                    cacheWidth: 800,
                    cacheHeight: 400,
                  ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        cs.scrim.withValues(alpha: 0.82),
                        cs.scrim.withValues(alpha: 0.34),
                      ],
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Align(
                        alignment: Alignment.topLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'offers.limitedOffer'.tr,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        title,
                        textAlign: TextAlign.right,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          height: 1.1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: cs.surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Directionality(
                          textDirection: TextDirection.ltr,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                (offer?.ctaLocalizationKey ??
                                        'offers.viewDetails')
                                    .tr,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: cs.onSurface,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 18,
                                color: cs.onSurface,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
