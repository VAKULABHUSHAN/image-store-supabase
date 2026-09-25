import 'package:supabase_flutter/supabase_flutter.dart';

/// Returns a temporary signed URL for a Supabase Storage path.
/// image_url from API is a storage path like "uuid/uuid.jpg" — NOT a URL.
/// Always call this before rendering an image.
Future<String?> getSignedUrl(String? storagePath) async {
  if (storagePath == null || storagePath.isEmpty) return null;
  try {
    final response = await Supabase.instance.client.storage
        .from('faces') // adjust bucket name if different
        .createSignedUrl(storagePath, 3600);
    return response;
  } catch (_) {
    return null;
  }
}
