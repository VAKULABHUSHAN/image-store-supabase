class PersonModel {
  final String id;
  final String userId;
  final String? name;
  final String? relationship;
  final String? imageUrl; // storage path — NOT a display URL
  final bool isKnown;
  final bool isActive;
  final DateTime createdAt;

  const PersonModel({
    required this.id,
    required this.userId,
    this.name,
    this.relationship,
    this.imageUrl,
    required this.isKnown,
    required this.isActive,
    required this.createdAt,
  });

  factory PersonModel.fromJson(Map<String, dynamic> json) => PersonModel(
        id:           json['id'] as String,
        userId:       json['user_id'] as String,
        name:         json['name'] as String?,
        relationship: json['relationship'] as String?,
        imageUrl:     json['image_url'] as String?,
        isKnown:      (json['is_known'] as bool?) ?? false,
        isActive:     (json['is_active'] as bool?) ?? true,
        createdAt:    DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id':           id,
        'user_id':      userId,
        'name':         name,
        'relationship': relationship,
        'image_url':    imageUrl,
        'is_known':     isKnown,
        'is_active':    isActive,
        'created_at':   createdAt.toIso8601String(),
      };

  PersonModel copyWith({
    String? name,
    String? relationship,
    String? imageUrl,
    bool? isKnown,
    bool? isActive,
  }) =>
      PersonModel(
        id:           id,
        userId:       userId,
        name:         name ?? this.name,
        relationship: relationship ?? this.relationship,
        imageUrl:     imageUrl ?? this.imageUrl,
        isKnown:      isKnown ?? this.isKnown,
        isActive:     isActive ?? this.isActive,
        createdAt:    createdAt,
      );
  String get displayName => name ?? 'Unnamed';

  String get initials {
    if (name == null || name!.isEmpty) return '?';
    final parts = name!.trim().split(' ');
    if (parts.length > 1) {
      return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }
}
