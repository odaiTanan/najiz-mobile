import 'dart:convert';

import 'package:get/get.dart';
import 'package:najiz_go_express/core/services/chat_websocket_service.dart';
import 'package:najiz_go_express/data/repositories/home_repository.dart';
import 'package:najiz_go_express/data/repositories/support_repository.dart';
import 'package:najiz_go_express/features/support/models/support_chat_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SupportChatController extends GetxController {
  SupportChatController({required this.token, SupportRepository? repository})
    : _repository = repository ?? SupportRepository();

  final String token;
  final SupportRepository _repository;

  final isLoading = true.obs;
  final isSending = false.obs;
  final errorMessage = RxnString();
  final messages = <SupportChatMessage>[].obs;
  final currentUserId = RxnInt();
  final conversation = Rxn<SupportConversation>();
  late final supportAgentName = ''.obs;

  ChatWebSocketService? _chatWs;
  String get _cacheScope => token.hashCode.abs().toString();
  String get _supportConversationKey => 'support_chat_conversation_$_cacheScope';
  String get _supportMessagesPrefix => 'support_chat_messages_$_cacheScope';
  String get _supportCurrentUserIdKey => 'support_chat_current_user_id_$_cacheScope';

  @override
  void onInit() {
    super.onInit();
    loadInitialData();
  }

  Future<void> loadInitialData() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      await _loadCachedData();
      final results = await Future.wait([
        _repository.getCurrentUserId(token: token),
        _repository.getUserConversation(token: token),
      ]);
      currentUserId.value = results[0] as int;
      conversation.value = results[1] as SupportConversation;
      _syncSupportAgentName();
      await _cacheConversationAndUser();
      await fetchMessages();
      await _connectRealtime();
    } on HomeApiException catch (e) {
      errorMessage.value = e.message;
    } catch (_) {
      errorMessage.value = 'support.loadFailed'.tr;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchMessages() async {
    final conv = conversation.value;
    if (conv == null) return;
    final loaded = await _repository.getMessages(
      token: token,
      conversationId: conv.id,
    );
    messages.assignAll(_sortMessages(loaded));
    _syncSupportAgentName();
    await _markIncomingAsRead();
    await _cacheMessages(conv.id, messages);
  }

  Future<void> _connectRealtime() async {
    final conv = conversation.value;
    if (conv == null) return;
    _chatWs = ChatWebSocketService(token: token);
    await _chatWs!.subscribeToConversation(
      conversationId: conv.id,
      onMessage: (payload) {
        final incoming = _toMessage(payload);
        if (messages.any((m) => m.id == incoming.id)) return;
        messages.add(incoming);
        _syncSupportAgentName();
        _markIncomingAsRead();
        final convId = conversation.value?.id;
        if (convId != null) {
          _cacheMessages(convId, messages);
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
          _cacheMessages(convId, messages);
        }
      },
    );
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || isSending.value) return;
    final conv = conversation.value;
    if (conv == null) return;

    isSending.value = true;
    try {
      final sent = await _repository.sendMessage(
        token: token,
        conversationId: conv.id,
        message: trimmed,
      );
      if (!messages.any((m) => m.id == sent.id)) {
        messages.add(sent);
        _syncSupportAgentName();
        final convId = conversation.value?.id;
        if (convId != null) {
          await _cacheMessages(convId, messages);
        }
      }
    } on HomeApiException catch (e) {
      throw e.message;
    } catch (_) {
      throw 'support.sendFailed'.tr;
    } finally {
      isSending.value = false;
    }
  }

  @override
  void onClose() {
    _chatWs?.disconnect();
    super.onClose();
  }

  Future<void> _loadCachedData() async {
    final prefs = await SharedPreferences.getInstance();

    final cachedUserId = prefs.getInt(_supportCurrentUserIdKey);
    if (cachedUserId != null) {
      currentUserId.value = cachedUserId;
    }

    final rawConversation = prefs.getString(_supportConversationKey);
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
        '$_supportMessagesPrefix${cachedConversation.id}',
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
    } catch (_) {
      // Ignore cache corruption and fallback to API.
    }
  }

  Future<void> _cacheConversationAndUser() async {
    final conv = conversation.value;
    if (conv == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _supportConversationKey,
      jsonEncode({
        'id': conv.id,
        'name': conv.name,
        'avatar': conv.avatar,
      }),
    );
    final uid = currentUserId.value;
    if (uid != null) {
      await prefs.setInt(_supportCurrentUserIdKey, uid);
    }
  }

  Future<void> _cacheMessages(
    int conversationId,
    List<SupportChatMessage> list,
  ) async {
    final prefs = await SharedPreferences.getInstance();
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
      '$_supportMessagesPrefix$conversationId',
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
    if (conv == null || myId == null) return;

    final unreadIncoming = messages
        .where((m) => m.senderId != myId && !m.isReadByMe)
        .map((m) => m.id)
        .toList(growable: false);
    if (unreadIncoming.isEmpty) return;

    try {
      await _repository.markMessagesAsRead(
        token: token,
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
    createdAt: (map['created_at'] ?? DateTime.now().toIso8601String()).toString(),
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
