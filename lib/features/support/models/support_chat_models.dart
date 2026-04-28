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
  final bool isReadByMe;
  final int readCount;

  const SupportChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.message,
    required this.createdAt,
    this.senderName,
    this.isReadByMe = false,
    this.readCount = 0,
  });

  bool get isReadByOthers => readCount > 0;

  SupportChatMessage copyWith({
    int? id,
    int? conversationId,
    int? senderId,
    String? message,
    String? createdAt,
    String? senderName,
    bool? isReadByMe,
    int? readCount,
  }) {
    return SupportChatMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      senderName: senderName ?? this.senderName,
      isReadByMe: isReadByMe ?? this.isReadByMe,
      readCount: readCount ?? this.readCount,
    );
  }
}
