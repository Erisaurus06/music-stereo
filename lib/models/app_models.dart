enum AppThemeMode { defaultBlue, chameleon, lavaLamp, system, custom }

enum CollectionType { playlist, folder, mix }

class AppCollection {
  final String id;
  final String name;
  final String? imagePath;
  final CollectionType type;
  final List<String> songIds;

  AppCollection({
    required this.id,
    required this.name,
    this.imagePath,
    required this.type,
    this.songIds = const [],
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'imagePath': imagePath,
    'type': type.toString(),
    'songIds': songIds,
  };

  factory AppCollection.fromJson(Map<String, dynamic> json) => AppCollection(
    id: json['id'],
    name: json['name'],
    imagePath: json['imagePath'],
    type: CollectionType.values.firstWhere((e) => e.toString() == json['type']),
    songIds: List<String>.from(json['songIds'] ?? []),
  );
}

class LrcLine {
  final Duration time;
  final String text;
  LrcLine({required this.time, required this.text});
}
