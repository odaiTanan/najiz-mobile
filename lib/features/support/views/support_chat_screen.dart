import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/constants/app_colors.dart';
import 'package:najiz_go_express/core/errors/user_feedback.dart';
import 'package:najiz_go_express/features/support/controllers/support_chat_controller.dart';
import 'package:najiz_go_express/features/support/models/support_chat_models.dart';

class SupportChatScreen extends StatefulWidget {
  const SupportChatScreen({super.key, required this.token});

  final String token;

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  late final SupportChatController _controller;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Worker? _messagesWorker;

  @override
  void initState() {
    super.initState();
    if (Get.isRegistered<SupportChatController>(tag: 'support-chat')) {
      Get.delete<SupportChatController>(tag: 'support-chat', force: true);
    }
    _controller = Get.put(
      SupportChatController(token: widget.token),
      tag: 'support-chat',
    );
    // Keep chat history in sync and always scroll to the newest message.
    _messagesWorker = ever<List<SupportChatMessage>>(
      _controller.messages,
      (_) => _scrollToBottom(),
    );
  }

  @override
  void dispose() {
    _messagesWorker?.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _messageController.text;
    if (text.trim().isEmpty) return;
    _messageController.clear();
    try {
      await _controller.sendMessage(text);
    } catch (e) {
      UserFeedback.showError(e, title: 'orders.error'.tr);
      _messageController.text = text;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: cs.onSurface),
        title: Text(
          'support.title'.tr,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: cs.onSurface,
          ),
        ),
      ),
      body: Obx(() {
        if (_controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_controller.errorMessage.value != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _controller.errorMessage.value!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: cs.error),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _controller.loadInitialData,
                    child: Text('support.retry'.tr),
                  ),
                ],
              ),
            ),
          );
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Color.alphaBlend(
                          AppColors.primary.withValues(alpha: 0.35),
                          cs.surface,
                        ),
                      ),
                    ),
                    child: const Icon(
                      Icons.support_agent_rounded,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _controller.supportAgentName.value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'support.onlineNow'.tr,
                          style: TextStyle(
                            color: Color(0xFF16A34A),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: cs.outlineVariant),
                  color: cs.surface,
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFFF8A00), Color(0xFF16A34A)],
                          begin: Alignment.centerRight,
                          end: Alignment.centerLeft,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.headset_mic_rounded, color: Colors.white),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _controller.supportAgentName.value,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'support.online'.tr,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerLowest,
                          border: Border(
                            top: BorderSide(
                              color: cs.outlineVariant,
                            ),
                          ),
                        ),
                        child: _controller.messages.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.chat_bubble_outline_rounded,
                                      size: 34,
                                      color: Color(0xFFFF8A00),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'support.startConversation'.tr,
                                      style: TextStyle(
                                        color: cs.onSurface,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                                itemCount: _controller.messages.length,
                                itemBuilder: (_, index) {
                                  final msg = _controller.messages[index];
                                  final isMe =
                                      msg.senderId == _controller.currentUserId.value;
                                  return Align(
                                    alignment: isMe
                                        ? AlignmentDirectional.centerStart
                                        : AlignmentDirectional.centerEnd,
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 9,
                                      ),
                                      constraints: const BoxConstraints(maxWidth: 320),
                                      decoration: BoxDecoration(
                                        color: isMe
                                            ? Color.alphaBlend(
                                                AppColors.primary.withValues(alpha: 0.2),
                                                cs.surface,
                                              )
                                            : Color.alphaBlend(
                                                const Color(0xFF16A34A)
                                                    .withValues(alpha: 0.16),
                                                cs.surface,
                                              ),
                                        borderRadius: BorderRadius.only(
                                          topLeft: const Radius.circular(12),
                                          topRight: const Radius.circular(12),
                                          bottomLeft: Radius.circular(isMe ? 4 : 12),
                                          bottomRight: Radius.circular(isMe ? 12 : 4),
                                        ),
                                        border: Border.all(
                                          color: isMe
                                              ? Color.alphaBlend(
                                                  AppColors.primary.withValues(alpha: 0.45),
                                                  cs.outlineVariant,
                                                )
                                              : Color.alphaBlend(
                                                  const Color(0xFF16A34A)
                                                      .withValues(alpha: 0.35),
                                                  cs.outlineVariant,
                                                ),
                                        ),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color(0x10000000),
                                            blurRadius: 4,
                                            offset: Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (!isMe && (msg.senderName ?? '').isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(bottom: 4),
                                              child: Text(
                                                msg.senderName!,
                                                style: const TextStyle(
                                                  color: Color(0xFF16A34A),
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          Text(
                                            msg.message,
                                            style: TextStyle(
                                              color: cs.onSurface,
                                              height: 1.35,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                _formatTime(msg.createdAt),
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: cs.onSurfaceVariant,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              if (isMe) ...[
                                                const SizedBox(width: 4),
                                                Icon(
                                                  msg.isReadByOthers
                                                      ? Icons.done_all_rounded
                                                      : Icons.done_rounded,
                                                  size: 14,
                                                  color: msg.isReadByOthers
                                                      ? cs.primary
                                                      : cs.onSurfaceVariant,
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                        decoration: BoxDecoration(
                          color: cs.surface,
                          border: Border(
                            top: BorderSide(color: cs.outlineVariant),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _messageController,
                                minLines: 1,
                                maxLines: 3,
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) => _send(),
                                decoration: InputDecoration(
                                  hintText: 'support.messageHint'.tr,
                                  filled: true,
                                  fillColor: cs.surfaceContainerHigh,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(999),
                                    borderSide: BorderSide(
                                      color: cs.outlineVariant,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(999),
                                    borderSide: BorderSide(
                                      color: cs.outlineVariant,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(999),
                                    borderSide: const BorderSide(
                                      color: AppColors.primary,
                                      width: 1.2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Obx(
                              () => CircleAvatar(
                                radius: 20,
                                backgroundColor: const Color(0xFFFF8A00),
                                child: IconButton(
                                  onPressed: _controller.isSending.value ? null : _send,
                                  icon: _controller.isSending.value
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.send_rounded,
                                          color: Colors.white,
                                          size: 19,
                                        ),
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
            ),
          ],
        );
      }),
    );
  }

  String _formatTime(String value) {
    final dt = DateTime.tryParse(value)?.toLocal();
    if (dt == null) return '';
    final h = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
