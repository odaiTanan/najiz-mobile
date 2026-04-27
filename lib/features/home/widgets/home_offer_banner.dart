import 'dart:async';

import 'package:flutter/material.dart';
import 'package:najiz_go_express/core/constants/app_colors.dart';
import 'package:najiz_go_express/data/models/offer_model.dart';
import 'package:najiz_go_express/features/home/widgets/network_image_with_fallback.dart';

class HomeOfferBanner extends StatefulWidget {
  final List<OfferModel> offers;

  const HomeOfferBanner({super.key, required this.offers});

  @override
  State<HomeOfferBanner> createState() => _HomeOfferBannerState();
}

class _HomeOfferBannerState extends State<HomeOfferBanner> {
  late final PageController _pageController;
  Timer? _autoPlayTimer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _setupAutoPlay();
  }

  @override
  void didUpdateWidget(covariant HomeOfferBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.offers.length != widget.offers.length) {
      _currentPage = 0;
      _setupAutoPlay();
    }
  }

  void _setupAutoPlay() {
    _autoPlayTimer?.cancel();
    if (widget.offers.length <= 1) return;
    _autoPlayTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_pageController.hasClients || widget.offers.isEmpty) return;
      final next = (_currentPage + 1) % widget.offers.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.offers.isEmpty) {
      return Container(
        height: 144,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: const Color(0xFF2F6D72),
        ),
        padding: const EdgeInsets.all(16),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _OfferTag(),
            SizedBox(height: 10),
            Text(
              'لا توجد عروض حالياً',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 150,
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: widget.offers.length,
              onPageChanged: (index) {
                setState(() => _currentPage = index);
              },
              itemBuilder: (_, index) {
                final offer = widget.offers[index];
                return _OfferSlide(offer: offer);
              },
            ),
            Positioned(
              left: 12,
              bottom: 10,
              child: Row(
                children: List.generate(widget.offers.length, (index) {
                  final isActive = index == _currentPage;
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(
                      Icons.circle,
                      size: 6,
                      color: isActive ? Colors.white : Colors.white54,
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfferSlide extends StatelessWidget {
  final OfferModel offer;

  const _OfferSlide({required this.offer});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SizedBox(
          height: 150,
          width: double.infinity,
          child: NetworkImageWithFallback(url: offer.image, fit: BoxFit.cover),
        ),
        Container(
          height: 150,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xCC113539), Color(0x66113539)],
            ),
          ),
        ),
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _OfferTag(),
                const SizedBox(height: 8),
                Text(
                  offer.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  offer.vendor?.name ?? 'استمتع بأفضل العروض الآن',
                  style: const TextStyle(
                    color: Color(0xFFEAF5F5),
                    fontSize: 11,
                  ),
                ),
                const Spacer(),
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'اطلب الآن',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _OfferTag extends StatelessWidget {
  const _OfferTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFF8A00),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text(
        'عرض محدود',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 9,
          letterSpacing: .4,
        ),
      ),
    );
  }
}
