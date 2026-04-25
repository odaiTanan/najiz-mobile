class SupportConversation {
  final int id;
  final String name;
  final String? avatar;

  const SupportConversation({
    required this.id,
    required this.name,
    this.avatar,
  });
}

class SupportChatMessage {
  final int id;
  final int conversationId;
  final int senderId;
  final String message;
  final String createdAt;
  final String? senderName;

  const SupportChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.message,
    required this.createdAt,
    this.senderName,
  });
}
