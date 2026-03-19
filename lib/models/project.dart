class Project {
  final int id;
  final String name;
  final String version;

  Project({required this.id, required this.name, required this.version});

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'],
      name: json['name'] ?? '',
      version: json['version'] ?? '1.0',
    );
  }
}
