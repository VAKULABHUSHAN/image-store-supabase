class MemoryCue {
  final String personId;
  final String? name;
  final String? relationship;
  final bool isKnown;
  final String? imageUrl;
  final String? firstSummary;
  final DateTime? firstOccurredAt;
  final String? lastSummary;
  final DateTime? lastOccurredAt;
  final double? matchDistance;

  const MemoryCue({
    required this.personId,
    this.name,
    this.relationship,
    required this.isKnown,
    this.imageUrl,
    this.firstSummary,
    this.firstOccurredAt,
    this.lastSummary,
    this.lastOccurredAt,
    this.matchDistance,
  });

  factory MemoryCue.fromJson(Map<String, dynamic> json) => MemoryCue(
        personId:       json['person_id'] as String,
        name:           json['name'] as String?,
        relationship:   json['relationship'] as String?,
        isKnown:        (json['is_known'] as bool?) ?? false,
        imageUrl:       json['image_url'] as String?,
        firstSummary:   json['first_summary'] as String?,
        firstOccurredAt: json['first_occurred_at'] != null
            ? DateTime.parse(json['first_occurred_at'] as String)
            : null,
        lastSummary:    json['last_summary'] as String?,
        lastOccurredAt: json['last_occurred_at'] != null
            ? DateTime.parse(json['last_occurred_at'] as String)
            : null,
        matchDistance:  (json['match_distance'] as num?)?.toDouble(),
      );
}
