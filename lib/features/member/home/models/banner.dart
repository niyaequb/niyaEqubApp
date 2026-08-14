class EqubBanner {
  final int? id;
  final String? title;
  final String? subtitle;
  final String? imageUrl;
  final String? linkUrl;

  EqubBanner({
    this.id,
    this.title,
    this.subtitle,
    this.imageUrl,
    this.linkUrl,
  });

  factory EqubBanner.fromJson(Map<String, dynamic> json) {
    return EqubBanner(
      id: json['id'] as int?,
      title: json['title']?.toString(),
      subtitle: json['subtitle']?.toString(),
      imageUrl: json['image_url']?.toString(),
      linkUrl: json['link']?.toString() ?? json['link_url']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'imageUrl': imageUrl,
      'linkUrl': linkUrl,
    };
  }
}
