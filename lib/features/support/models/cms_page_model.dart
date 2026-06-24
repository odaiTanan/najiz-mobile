class CmsPage {
  const CmsPage({
    required this.slug,
    required this.title,
    required this.content,
    this.updatedAt,
  });

  final String slug;
  final String title;
  final String content;
  final String? updatedAt;

  factory CmsPage.fromJson(Map<String, dynamic> json) {
    return CmsPage(
      slug: (json['slug'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }
}
