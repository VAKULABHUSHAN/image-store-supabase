class InteractionModel {
  final String id;
  final String userId;
  final String personId;
  final String? firstTranscript;
  final String? firstSummary;
  final DateTime? firstOccurredAt;
  final String? lastTranscript;
  final String? lastSummary;
  final DateTime? lastOccurredAt;
  final DateTime updatedAt;

  const InteractionModel({
    required this.id,
    required this.userId,
    required this.personId,
    this.firstTranscript,
    this.firstSummary,
    this.firstOccurredAt,
    this.lastTranscript,
    this.lastSummary,
    this.lastOccurredAt,
    required this.updatedAt,
  });

  factory InteractionModel.fromJson(Map<String, dynamic> json) =>
      InteractionModel(
        id:               json['id'] as String,
        userId:           json['user_id'] as String,
        personId:         json['person_id'] as String,
        firstTranscript:  json['first_transcript'] as String?,
        firstSummary:     json['first_summary'] as String?,
        firstOccurredAt:  json['first_occurred_at'] != null
            ? DateTime.parse(json['first_occurred_at'] as String)
            : null,
        lastTranscript:   json['last_transcript'] as String?,
        lastSummary:      json['last_summary'] as String?,
        lastOccurredAt:   json['last_occurred_at'] != null
            ? DateTime.parse(json['last_occurred_at'] as String)
            : null,
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
}
