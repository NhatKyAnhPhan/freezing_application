class AppModel {
  const AppModel({
    required this.name,
    required this.packageName,
    this.iconCodePoint,
    this.isFrozen = false,
  });

  final String name;
  final String packageName;
  final int? iconCodePoint;
  final bool isFrozen;

  AppModel copyWith({bool? isFrozen}) {
    return AppModel(
      name: name,
      packageName: packageName,
      iconCodePoint: iconCodePoint,
      isFrozen: isFrozen ?? this.isFrozen,
    );
  }

  factory AppModel.fromMap(Map<Object?, Object?> map) {
    return AppModel(
      name: map['name'] as String? ?? map['packageName'] as String? ?? 'Unknown app',
      packageName: map['packageName'] as String? ?? '',
      iconCodePoint: map['iconCodePoint'] as int?,
      isFrozen: map['isFrozen'] as bool? ?? false,
    );
  }
}