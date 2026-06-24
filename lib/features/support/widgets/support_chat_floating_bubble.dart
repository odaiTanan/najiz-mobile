import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/constants/app_colors.dart';
import 'package:najiz_go_express/core/routes/app_routes.dart';
import 'package:najiz_go_express/core/services/auth_state_manager.dart';
import 'package:najiz_go_express/features/support/services/support_chat_presence_service.dart';
import 'package:najiz_go_express/features/support/services/support_dependencies.dart';

class SupportChatFloatingBubble extends StatefulWidget {
  const SupportChatFloatingBubble({super.key});

  static const double size = 52;
  static const double _dragStartThreshold = 14;
  static const double _dismissZoneMinHeight = 84;
  static const double _dismissZoneMaxHeight = 112;
  static const double _dismissZoneHeightFactor = 0.13;

  @override
  State<SupportChatFloatingBubble> createState() =>
      _SupportChatFloatingBubbleState();
}

class _SupportChatFloatingBubbleState extends State<SupportChatFloatingBubble> {
  Offset? _position;
  Offset? _dragOrigin;
  Offset? _positionAtDragStart;
  bool _isDragging = false;
  bool _showDismissZone = false;
  bool _hoverDismissZone = false;

  Offset _defaultPosition(BoxConstraints constraints) {
    const padding = 16.0;
    return Offset(
      constraints.maxWidth - SupportChatFloatingBubble.size - padding,
      constraints.maxHeight - SupportChatFloatingBubble.size - padding,
    );
  }

  Offset _clampPosition(Offset value, BoxConstraints constraints) {
    final maxX = (constraints.maxWidth - SupportChatFloatingBubble.size)
        .clamp(0.0, double.infinity);
    final maxY = (constraints.maxHeight - SupportChatFloatingBubble.size)
        .clamp(0.0, double.infinity);
    return Offset(
      value.dx.clamp(0.0, maxX),
      value.dy.clamp(0.0, maxY),
    );
  }

  Offset _bubbleCenter(Offset topLeft) {
    return topLeft + Offset(SupportChatFloatingBubble.size / 2, SupportChatFloatingBubble.size / 2);
  }

  double _dismissZoneHeight(BoxConstraints constraints) {
    return (constraints.maxHeight * SupportChatFloatingBubble._dismissZoneHeightFactor)
        .clamp(
          SupportChatFloatingBubble._dismissZoneMinHeight,
          SupportChatFloatingBubble._dismissZoneMaxHeight,
        );
  }

  bool _isInDismissZone(
    Offset topLeft,
    BoxConstraints constraints,
  ) {
    final zoneTop = constraints.maxHeight - _dismissZoneHeight(constraints);
    return _bubbleCenter(topLeft).dy >= zoneTop;
  }

  void _openChat() {
    final auth = Get.find<AuthStateManager>();
    final token = auth.token.value?.trim();
    if (token == null || token.isEmpty) return;
    AppRoutes.openSupportChat(token: token);
  }

  Future<void> _dismissBubble() async {
    await resolveSupportChatPresenceService().dismissFloatingBubble();
    if (!mounted) return;
    setState(() {
      _position = null;
      _isDragging = false;
      _showDismissZone = false;
      _hoverDismissZone = false;
    });
  }

  Widget _buildBubble({
    required bool hasUnread,
    required ColorScheme cs,
  }) {
    return Material(
      elevation: 6,
      color: AppColors.primary,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: SupportChatFloatingBubble.size,
        height: SupportChatFloatingBubble.size,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.chat_bubble_rounded,
              color: cs.onPrimary,
              size: 24,
            ),
            if (hasUnread)
              PositionedDirectional(
                top: 8,
                end: 8,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary,
                      width: 2,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDismissZone({
    required ColorScheme cs,
    required BoxConstraints constraints,
  }) {
    final zoneHeight = _dismissZoneHeight(constraints);

    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: _showDismissZone ? 1 : 0,
        duration: const Duration(milliseconds: 160),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            width: constraints.maxWidth,
            height: zoneHeight,
            child: ClipRect(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      cs.surface.withValues(alpha: 0),
                      cs.errorContainer.withValues(alpha: 0.92),
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.bottomCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth - 24,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedScale(
                              scale: _hoverDismissZone ? 1.06 : 1,
                              duration: const Duration(milliseconds: 140),
                              child: Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: _hoverDismissZone ? cs.error : cs.surface,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: cs.error.withValues(alpha: 0.55),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.12),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.close_rounded,
                                  color: _hoverDismissZone ? cs.onError : cs.error,
                                  size: 24,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'support.dragToHide'.tr,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: cs.onErrorContainer,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                                height: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Offset _resolvedPosition({
    required BoxConstraints constraints,
    required SupportChatPresenceService presence,
  }) {
    if (_position != null) {
      return _clampPosition(_position!, constraints);
    }
    final x = presence.bubblePositionX.value;
    final y = presence.bubblePositionY.value;
    if (x != null && y != null) {
      return _clampPosition(Offset(x, y), constraints);
    }
    return _defaultPosition(constraints);
  }

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthStateManager>();
    final cs = Theme.of(context).colorScheme;

    return Obx(() {
      if (auth.isGuest) {
        return const SizedBox.shrink();
      }

      final presence = resolveSupportChatPresenceService();
      if (!presence.shouldShowFloatingBubble) {
        return const SizedBox.shrink();
      }

      final hasUnread = presence.hasUnreadIncoming.value;

      return LayoutBuilder(
        builder: (context, constraints) {
          final current = _resolvedPosition(
            constraints: constraints,
            presence: presence,
          );

          return Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              _buildDismissZone(cs: cs, constraints: constraints),
              Positioned(
                left: current.dx,
                top: current.dy,
                width: SupportChatFloatingBubble.size,
                height: SupportChatFloatingBubble.size,
                child: Semantics(
                  button: true,
                  label: hasUnread
                      ? 'support.floatingUnread'.tr
                      : 'support.floatingActive'.tr,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (details) {
                      _isDragging = false;
                      _showDismissZone = false;
                      _hoverDismissZone = false;
                      _dragOrigin = details.globalPosition;
                      _positionAtDragStart = current;
                    },
                    onPanUpdate: (details) {
                      final dragOrigin = _dragOrigin;
                      final startPos = _positionAtDragStart;
                      if (dragOrigin == null || startPos == null) return;

                      final delta = details.globalPosition - dragOrigin;
                      if (!_isDragging) {
                        if (delta.distance < SupportChatFloatingBubble._dragStartThreshold) {
                          return;
                        }
                        _isDragging = true;
                      }

                      final next = _clampPosition(startPos + delta, constraints);
                      final inZone = _isInDismissZone(next, constraints);
                      setState(() {
                        _position = next;
                        _showDismissZone = true;
                        _hoverDismissZone = inZone;
                      });
                    },
                    onPanEnd: (_) async {
                      final finalPos = _clampPosition(
                        _position ?? current,
                        constraints,
                      );

                      if (_isDragging && _isInDismissZone(finalPos, constraints)) {
                        await _dismissBubble();
                      } else if (_isDragging) {
                        setState(() {
                          _position = finalPos;
                          _showDismissZone = false;
                          _hoverDismissZone = false;
                          _isDragging = false;
                        });
                        await presence.saveFloatingBubblePosition(
                          x: finalPos.dx,
                          y: finalPos.dy,
                        );
                      } else {
                        _openChat();
                        setState(() {
                          _showDismissZone = false;
                          _hoverDismissZone = false;
                        });
                      }

                      _dragOrigin = null;
                      _positionAtDragStart = null;
                      _isDragging = false;
                    },
                    onPanCancel: () {
                      setState(() {
                        _showDismissZone = false;
                        _hoverDismissZone = false;
                        _isDragging = false;
                      });
                      _dragOrigin = null;
                      _positionAtDragStart = null;
                    },
                    child: _buildBubble(hasUnread: hasUnread, cs: cs),
                  ),
                ),
              ),
            ],
          );
        },
      );
    });
  }
}
