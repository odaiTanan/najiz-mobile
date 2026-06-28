import 'package:flutter/material.dart';
import 'package:najiz_go_express/core/constants/app_colors.dart';

/// Swipe-to-confirm bar: drag from left to right across the track.
class SlideToConfirmBar extends StatefulWidget {
  const SlideToConfirmBar({
    super.key,
    required this.label,
    required this.totalLabel,
    required this.onConfirmed,
    this.height = 56,
  });

  final String label;
  final String totalLabel;
  final VoidCallback onConfirmed;
  final double height;

  @override
  State<SlideToConfirmBar> createState() => _SlideToConfirmBarState();
}

class _SlideToConfirmBarState extends State<SlideToConfirmBar> {
  static const double _thumbSize = 48;
  static const double _horizontalPadding = 4;
  static const double _confirmThreshold = 0.82;

  double _dragOffset = 0;
  bool _completed = false;

  void _resetThumb() {
    if (!mounted) return;
    setState(() {
      _dragOffset = 0;
      _completed = false;
    });
  }

  void _handleConfirmed(double maxDrag) {
    if (_completed) return;
    setState(() {
      _completed = true;
      _dragOffset = maxDrag;
    });
    widget.onConfirmed();
    Future<void>.delayed(const Duration(milliseconds: 250), _resetThumb);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxDrag = (constraints.maxWidth -
                _thumbSize -
                (_horizontalPadding * 2))
            .clamp(0.0, double.infinity);

        void onDragUpdate(DragUpdateDetails details) {
          if (_completed) return;
          setState(() {
            _dragOffset = (_dragOffset + details.delta.dx).clamp(0, maxDrag);
          });
        }

        void onDragEnd(DragEndDetails details) {
          if (_completed) return;
          if (maxDrag <= 0) {
            _handleConfirmed(maxDrag);
            return;
          }
          if (_dragOffset >= maxDrag * _confirmThreshold) {
            _handleConfirmed(maxDrag);
            return;
          }
          setState(() => _dragOffset = 0);
        }

        return GestureDetector(
          onHorizontalDragUpdate: onDragUpdate,
          onHorizontalDragEnd: onDragEnd,
          child: Container(
            height: widget.height,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 18,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 62),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.totalLabel,
                        maxLines: 1,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: _horizontalPadding,
                  bottom: _horizontalPadding,
                  left: _horizontalPadding + _dragOffset,
                  child: Container(
                    width: _thumbSize,
                    height: _thumbSize,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x26000000),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.primary,
                      size: 28,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
