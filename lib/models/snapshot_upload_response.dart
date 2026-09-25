class SnapshotUploadResponse {
  final String personId;
  final String imageUrl;    // storage path
  final String? signedUrl;  // displayable, expires 1 hr

  const SnapshotUploadResponse({
    required this.personId,
    required this.imageUrl,
    this.signedUrl,
  });

  factory SnapshotUploadResponse.fromJson(Map<String, dynamic> json) =>
      SnapshotUploadResponse(
        personId:  json['person_id'] as String,
        imageUrl:  json['image_url'] as String,
        signedUrl: json['signed_url'] as String?,
      );
}
