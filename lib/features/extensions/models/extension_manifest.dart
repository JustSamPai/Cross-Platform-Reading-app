class ExtensionManifest {
  const ExtensionManifest({
    required this.id,
    required this.name,
    required this.site,
    required this.language,
    required this.version,
    required this.url,
    required this.iconUrl,
    required this.repositoryUrl,
    this.sourceCode,
    this.downloadedAt,
  });

  final String id;
  final String name;
  final String site;
  final String language;
  final String version;
  final String url;
  final String iconUrl;
  final String repositoryUrl;
  final String? sourceCode;
  final DateTime? downloadedAt;

  String get key => '$repositoryUrl::$id';

  bool get isDownloaded => downloadedAt != null;

  ExtensionManifest copyWith({
    String? sourceCode,
    DateTime? downloadedAt,
  }) {
    return ExtensionManifest(
      id: id,
      name: name,
      site: site,
      language: language,
      version: version,
      url: url,
      iconUrl: iconUrl,
      repositoryUrl: repositoryUrl,
      sourceCode: sourceCode ?? this.sourceCode,
      downloadedAt: downloadedAt ?? this.downloadedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'site': site,
      'language': language,
      'version': version,
      'url': url,
      'iconUrl': iconUrl,
      'repositoryUrl': repositoryUrl,
      'sourceCode': sourceCode,
      'downloadedAt': downloadedAt?.toIso8601String(),
    };
  }

  factory ExtensionManifest.fromMap(Map<dynamic, dynamic> map) {
    return ExtensionManifest(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? 'Untitled extension',
      site: map['site'] as String? ?? '',
      language: map['language'] as String? ?? '',
      version: map['version'] as String? ?? '',
      url: map['url'] as String? ?? '',
      iconUrl: map['iconUrl'] as String? ?? '',
      repositoryUrl: map['repositoryUrl'] as String? ?? '',
      sourceCode: map['sourceCode'] as String?,
      downloadedAt: DateTime.tryParse(map['downloadedAt'] as String? ?? ''),
    );
  }

  factory ExtensionManifest.fromJson({
    required Map<String, dynamic> json,
    required String repositoryUrl,
  }) {
    final id = json['id']?.toString() ?? json['name']?.toString() ?? '';

    return ExtensionManifest(
      id: id,
      name: json['name']?.toString() ?? id,
      site: json['site']?.toString() ?? '',
      language: json['lang']?.toString() ?? json['language']?.toString() ?? '',
      version: json['version']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      iconUrl: json['iconUrl']?.toString() ?? '',
      repositoryUrl: repositoryUrl,
    );
  }
}
