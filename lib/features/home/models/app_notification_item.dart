class AppNotificationItem {
  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final Map<String, dynamic> data;
  final bool isRead;

  const AppNotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.data,
    required this.isRead,
  });

  AppNotificationItem copyWith({
    String? id,
    String? title,
    String? body,
    DateTime? createdAt,
    Map<String, dynamic>? data,
    bool? isRead,
  }) {
    return AppNotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      data: data ?? this.data,
      isRead: isRead ?? this.isRead,
    );
  }

  factory AppNotificationItem.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    final mapData = <String, dynamic>{};
    if (rawData is Map) {
      for (final entry in rawData.entries) {
        mapData[entry.key.toString()] = entry.value;
      }
    }
    return AppNotificationItem(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      createdAt:
          DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
      data: mapData,
      isRead: json['is_read'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'created_at': createdAt.toIso8601String(),
    'data': data,
    'is_read': isRead,
  };
}
