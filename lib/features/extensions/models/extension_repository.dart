class ExtensionRepository {
  const ExtensionRepository({
    required this.url,
    required this.addedAt,
  });

  final String url;
  final DateTime addedAt;

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'addedAt': addedAt.toIso8601String(),
    };
  }

  factory ExtensionRepository.fromMap(Map<dynamic, dynamic> map) {
    return ExtensionRepository(
      url: map['url'] as String? ?? '',
      addedAt:
          DateTime.tryParse(map['addedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  factory ExtensionRepository.create(String url) {
    return ExtensionRepository(
      url: url.trim(),
      addedAt: DateTime.now(),
    );
  }
}
