import 'dart:async';
import 'dart:convert';

import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/services/auth_state_manager.dart';
import 'package:najiz_go_express/core/services/chat_websocket_service.dart';
import 'package:najiz_go_express/features/support/errors/support_api_exception.dart';
import 'package:najiz_go_express/features/support/models/support_chat_models.dart';
import 'package:najiz_go_express/features/support/repositories/support_repository.dart';
import 'package:najiz_go_express/features/support/services/support_dependencies.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SupportChatPresenceService extends GetxService {
  SupportChatPresenceService({SupportRepository? repository})
      : _repository = repository ?? resolveSupportRepository();

  final SupportRepository _repository;

  final isLoading = false.obs;
  final isSending = false.obs;
  final errorMessage = RxnString();
  final messages = <SupportChatMessage>[].obs;
  final currentUserId = RxnInt();
  final conversation = Rxn<SupportConversation>();
  final supportAgentName = ''.obs;
  final hasUnreadIncoming = false.obs;
  final isConversationActive = false.obs;
  final isChatScreenOpen = false.obs;
  final isBubbleDismissed = false.obs;
  final hasEngagedSupportChat = false.obs;
  final bubblePositionX = RxnDouble();
  final bubblePositionY = RxnDouble();

  ChatWebSocketService? _chatWs;
  String? _token;
  Worker? _authWorker;

  String? get token => _token;

  bool get shouldShowFloatingBubble =>
      isConversationActive.value &&
      !isChatScreenOpen.value &&
      !isBubbleDismissed.value;

  @override
  void onInit() {
    super.onInit();
    if (!Get.isRegistered<AuthStateManager>()) return;
    final auth = Get.find<AuthStateManager>();
    _authWorker = ever<String?>(auth.token, (value) {
      unawaited(bindToken(value));
    });
    unawaited(bindToken(auth.token.value));
  }

  @override
  void onClose() {
    _authWorker?.dispose();
    unawaited(_disconnect());
    super.onClose();
  }

  Future<void> bindToken(String? token) async {
    final normalized = token?.trim();
    if (normalized == _token) return;
    await _disconnect();
    _token = (normalized == null || normalized.isEmpty) ? null : normalized;
    if (_token == null) {
      _resetState();
      return;
    }
    await ensureLoaded(_token!);
  }

  Future<void> ensureLoaded(String token, {bool force = false}) async {
    if (!force && _token == token.trim() && conversation.value != null) {
      _syncDerivedState();
      return;
    }
    _token = token.trim();
    await loadInitialData();
  }

  Future<void> loadInitialData() async {
    final authToken = _token;
    if (authToken == null || authToken.isEmpty) return;

    isLoading.value = true;
    errorMessage.value = null;
    try {
      await _loadCachedData();
      await _loadBubbleUiState();
      _syncDerivedState();
      final results = await Future.wait([
        _repository.getCurrentUserId(token: authToken),
        _repository.getUserConversation(token: authToken),
      ]);
      currentUserId.value = results[0] as int;
      conversation.value = results[1] as SupportConversation;
      _syncSupportAgentName();
      await _cacheConversationAndUser();
      await fetchMessages();
      await _connectRealtime();
    } on SupportApiException catch (e) {
      errorMessage.value = e.message;
    } catch (_) {
      errorMessage.value = 'support.loadFailed'.tr;
    } finally {
      isLoading.value = false;
      _syncDerivedState();
    }
  }

  Future<void> fetchMessages() async {
    final conv = conversation.value;
    final authToken = _token;
    if (conv == null || authToken == null) return;
    final loaded = await _repository.getMessages(
      token: authToken,
      conversationId: conv.id,
    );
    messages.assignAll(_sortMessages(loaded));
    _syncSupportAgentName();
    if (loaded.isNotEmpty && !hasEngagedSupportChat.value) {
      hasEngagedSupportChat.value = true;
      unawaited(_persistEngaged(true));
    }
    if (isChatScreenOpen.value) {
      await _markIncomingAsRead();
    } else {
      _syncDerivedState();
    }
    await _cacheMessages(conv.id, messages);
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || isSending.value) return;
    final conv = conversation.value;
    final authToken = _token;
    if (conv == null || authToken == null) return;

    isSending.value = true;
    try {
      final sent = await _repository.sendMessage(
        token: authToken,
        conversationId: conv.id,
        message: trimmed,
      );
      if (!messages.any((m) => m.id == sent.id)) {
        messages.add(sent);
        _syncSupportAgentName();
        await markConversationEngaged();
        await _cacheMessages(conv.id, messages);
      }
    } on SupportApiException catch (e) {
      throw e.message;
    } catch (_) {
      throw 'support.sendFailed'.tr;
    } finally {
      isSending.value = false;
    }
  }

  void setChatScreenOpen(bool open) {
    if (isChatScreenOpen.value == open) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (isChatScreenOpen.value == open) return;
      isChatScreenOpen.value = open;
      if (open) {
        unawaited(markConversationEngaged());
        unawaited(_markIncomingAsRead());
      } else {
        _syncDerivedState();
      }
    });
  }

  Future<void> dismissFloatingBubble() async {
    isBubbleDismissed.value = true;
    await _persistBubbleDismissed(true);
  }

  Future<void> markConversationEngaged() async {
    final conv = conversation.value;
    if (conv == null || conv.id <= 0) return;

    if (!hasEngagedSupportChat.value) {
      hasEngagedSupportChat.value = true;
      await _persistEngaged(true);
    }
    if (isBubbleDismissed.value) {
      isBubbleDismissed.value = false;
      await _persistBubbleDismissed(false);
    }
    _syncDerivedState();
  }

  Future<void> saveFloatingBubblePosition({
    required double x,
    required double y,
  }) async {
    bubblePositionX.value = x;
    bubblePositionY.value = y;
    final authToken = _token;
    if (authToken == null) return;
    final prefs = await SharedPreferences.getInstance();
    final scope = authToken.hashCode.abs().toString();
    await prefs.setDouble('support_bubble_x_$scope', x);
    await prefs.setDouble('support_bubble_y_$scope', y);
  }

  Future<void> _connectRealtime() async {
    final conv = conversation.value;
    final authToken = _token;
    if (conv == null || authToken == null) return;
    _chatWs = ChatWebSocketService(token: authToken);
    await _chatWs!.subscribeToConversation(
      conversationId: conv.id,
      onMessage: (payload) {
        final incoming = _toMessage(payload);
        if (messages.any((m) => m.id == incoming.id)) return;
        messages.add(incoming);
        _syncSupportAgentName();
        if (isChatScreenOpen.value) {
          unawaited(_markIncomingAsRead());
        } else {
          _syncDerivedState();
        }
        final convId = conversation.value?.id;
        if (convId != null) {
          unawaited(_cacheMessages(convId, messages));
        }
      },
      onMessageRead: (payload) {
        final messageId = _asInt(payload['message_id']);
        if (messageId == null) return;
        final myId = currentUserId.value;
        final senderId = _asInt(payload['sender_id']);
        if (myId != null && senderId != null && senderId != myId) {
          return;
        }

        var changed = false;
        final updated = messages.map((m) {
          if (m.id != messageId) return m;
          changed = true;
          final nextCount = m.readCount > 0 ? m.readCount : 1;
          return m.copyWith(readCount: nextCount);
        }).toList(growable: false);
        if (!changed) return;
        messages.assignAll(updated);
        final convId = conversation.value?.id;
        if (convId != null) {
          unawaited(_cacheMessages(convId, messages));
        }
      },
    );
  }

  Future<void> _disconnect() async {
    await _chatWs?.disconnect();
    _chatWs = null;
  }

  void _resetState() {
    messages.clear();
    conversation.value = null;
    currentUserId.value = null;
    supportAgentName.value = '';
    errorMessage.value = null;
    isLoading.value = false;
    isSending.value = false;
    hasUnreadIncoming.value = false;
    isConversationActive.value = false;
    isChatScreenOpen.value = false;
    isBubbleDismissed.value = false;
    hasEngagedSupportChat.value = false;
    bubblePositionX.value = null;
    bubblePositionY.value = null;
  }

  void _syncDerivedState() {
    final conv = conversation.value;
    isConversationActive.value = conv != null &&
        conv.id > 0 &&
        (hasEngagedSupportChat.value || messages.isNotEmpty);

    final myId = currentUserId.value;
    if (myId == null || isChatScreenOpen.value) {
      hasUnreadIncoming.value = false;
      return;
    }
    hasUnreadIncoming.value = messages.any(
      (m) => m.senderId != myId && !m.isReadByMe,
    );
    if (hasUnreadIncoming.value && isBubbleDismissed.value) {
      isBubbleDismissed.value = false;
      unawaited(_persistBubbleDismissed(false));
    }
  }

  Future<void> _loadBubbleUiState() async {
    final authToken = _token;
    if (authToken == null) return;
    final prefs = await SharedPreferences.getInstance();
    final scope = authToken.hashCode.abs().toString();
    isBubbleDismissed.value =
        prefs.getBool('support_bubble_dismissed_$scope') ?? false;
    hasEngagedSupportChat.value =
        prefs.getBool('support_chat_engaged_$scope') ?? false;
    final x = prefs.getDouble('support_bubble_x_$scope');
    final y = prefs.getDouble('support_bubble_y_$scope');
    bubblePositionX.value = x;
    bubblePositionY.value = y;
  }

  Future<void> _persistBubbleDismissed(bool dismissed) async {
    final authToken = _token;
    if (authToken == null) return;
    final prefs = await SharedPreferences.getInstance();
    final scope = authToken.hashCode.abs().toString();
    await prefs.setBool('support_bubble_dismissed_$scope', dismissed);
  }

  Future<void> _persistEngaged(bool engaged) async {
    final authToken = _token;
    if (authToken == null) return;
    final prefs = await SharedPreferences.getInstance();
    final scope = authToken.hashCode.abs().toString();
    await prefs.setBool('support_chat_engaged_$scope', engaged);
  }

  Future<void> _loadCachedData() async {
    final authToken = _token;
    if (authToken == null) return;
    final prefs = await SharedPreferences.getInstance();
    final cacheScope = authToken.hashCode.abs().toString();
    final supportConversationKey = 'support_chat_conversation_$cacheScope';
    final supportMessagesPrefix = 'support_chat_messages_$cacheScope';
    final supportCurrentUserIdKey = 'support_chat_current_user_id_$cacheScope';

    final cachedUserId = prefs.getInt(supportCurrentUserIdKey);
    if (cachedUserId != null) {
      currentUserId.value = cachedUserId;
    }

    final rawConversation = prefs.getString(supportConversationKey);
    if (rawConversation == null || rawConversation.trim().isEmpty) return;

    try {
      final decoded = jsonDecode(rawConversation);
      if (decoded is! Map) return;
      final map = decoded.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      final cachedConversation = SupportConversation(
        id: _asInt(map['id']) ?? 0,
        name: (map['name'] ?? 'support.agentTitle'.tr).toString(),
        avatar: map['avatar']?.toString(),
      );
      if (cachedConversation.id == 0) return;
      conversation.value = cachedConversation;

      final rawMessages = prefs.getString(
        '$supportMessagesPrefix${cachedConversation.id}',
      );
      if (rawMessages == null || rawMessages.trim().isEmpty) return;
      final decodedMessages = jsonDecode(rawMessages);
      if (decodedMessages is! List) return;
      final cachedMessages = decodedMessages
          .whereType<Map>()
          .map((m) => m.map((k, v) => MapEntry(k.toString(), v)))
          .map(_toMessage)
          .toList(growable: false);
      messages.assignAll(_sortMessages(cachedMessages));
      _syncSupportAgentName();
      _syncDerivedState();
    } catch (_) {
      // Ignore cache corruption and fallback to API.
    }
  }

  Future<void> _cacheConversationAndUser() async {
    final conv = conversation.value;
    final authToken = _token;
    if (conv == null || authToken == null) return;
    final prefs = await SharedPreferences.getInstance();
    final cacheScope = authToken.hashCode.abs().toString();
    await prefs.setString(
      'support_chat_conversation_$cacheScope',
      jsonEncode({
        'id': conv.id,
        'name': conv.name,
        'avatar': conv.avatar,
      }),
    );
    final uid = currentUserId.value;
    if (uid != null) {
      await prefs.setInt('support_chat_current_user_id_$cacheScope', uid);
    }
  }

  Future<void> _cacheMessages(
    int conversationId,
    List<SupportChatMessage> list,
  ) async {
    final authToken = _token;
    if (authToken == null) return;
    final prefs = await SharedPreferences.getInstance();
    final cacheScope = authToken.hashCode.abs().toString();
    final normalized = _sortMessages(list).map((m) {
      return {
        'id': m.id,
        'conversation_id': m.conversationId,
        'sender_id': m.senderId,
        'message': m.message,
        'created_at': m.createdAt,
        'is_read_by_me': m.isReadByMe,
        'read_count': m.readCount,
        'sender': {'name': m.senderName},
      };
    }).toList(growable: false);
    await prefs.setString(
      'support_chat_messages_$cacheScope$conversationId',
      jsonEncode(normalized),
    );
  }

  List<SupportChatMessage> _sortMessages(List<SupportChatMessage> list) {
    final sorted = [...list];
    sorted.sort((a, b) {
      final ad = DateTime.tryParse(a.createdAt);
      final bd = DateTime.tryParse(b.createdAt);
      if (ad == null && bd == null) return a.id.compareTo(b.id);
      if (ad == null) return -1;
      if (bd == null) return 1;
      final byDate = ad.compareTo(bd);
      if (byDate != 0) return byDate;
      return a.id.compareTo(b.id);
    });
    return sorted;
  }

  void _syncSupportAgentName() {
    final myId = currentUserId.value;
    SupportChatMessage? fromSupport;
    for (final message in messages.reversed) {
      final hasName = (message.senderName ?? '').trim().isNotEmpty;
      final isSupportSide = myId == null || message.senderId != myId;
      if (hasName && isSupportSide) {
        fromSupport = message;
        break;
      }
    }
    final fallbackFromConversation = conversation.value?.name.trim();
    supportAgentName.value =
        fromSupport?.senderName?.trim().isNotEmpty == true
        ? fromSupport!.senderName!.trim()
        : (fallbackFromConversation?.isNotEmpty == true
              ? fallbackFromConversation!
              : 'support.customerService'.tr);
  }

  Future<void> _markIncomingAsRead() async {
    final conv = conversation.value;
    final myId = currentUserId.value;
    final authToken = _token;
    if (conv == null || myId == null || authToken == null) return;

    final unreadIncoming = messages
        .where((m) => m.senderId != myId && !m.isReadByMe)
        .map((m) => m.id)
        .toList(growable: false);
    if (unreadIncoming.isEmpty) {
      _syncDerivedState();
      return;
    }

    try {
      await _repository.markMessagesAsRead(
        token: authToken,
        conversationId: conv.id,
        messageIds: unreadIncoming,
      );
      final updated = messages.map((m) {
        if (unreadIncoming.contains(m.id)) {
          return m.copyWith(isReadByMe: true);
        }
        return m;
      }).toList(growable: false);
      messages.assignAll(updated);
      await _cacheMessages(conv.id, messages);
    } catch (_) {
      // Ignore read-receipt failures and keep chat usable.
    } finally {
      _syncDerivedState();
    }
  }
}

SupportChatMessage _toMessage(Map<String, dynamic> map) {
  final sender = map['sender'];
  String? senderName;
  if (sender is Map) {
    senderName = sender['name']?.toString();
  }
  return SupportChatMessage(
    id: _asInt(map['id']) ?? DateTime.now().millisecondsSinceEpoch,
    conversationId: _asInt(map['conversation_id']) ?? 0,
    senderId: _asInt(map['sender_id']) ?? 0,
    message: (map['message'] ?? '').toString(),
    createdAt:
        (map['created_at'] ?? DateTime.now().toIso8601String()).toString(),
    senderName: senderName,
    isReadByMe: _asBool(map['is_read_by_me']),
    readCount: _asInt(map['read_count']) ?? 0,
  );
}

int? _asInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '');
}

bool _asBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value == 1;
  final normalized = value?.toString().toLowerCase();
  return normalized == '1' || normalized == 'true';
}
