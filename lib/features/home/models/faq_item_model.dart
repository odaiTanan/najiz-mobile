class FaqItem {
  const FaqItem({
    required this.id,
    required this.question,
    required this.answer,
    required this.sortOrder,
  });

  final int id;
  final String question;
  final String answer;
  final int sortOrder;

  factory FaqItem.fromJson(Map<String, dynamic> json) {
    return FaqItem(
      id: _asInt(json['id']) ?? 0,
      question: (json['question'] ?? '').toString(),
      answer: (json['answer'] ?? '').toString(),
      sortOrder: _asInt(json['sort_order']) ?? 0,
    );
  }
}

int? _asInt(dynamic v) {
  if (v is int) return v;
  return int.tryParse(v?.toString() ?? '');
}
