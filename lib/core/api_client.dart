import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config.dart';

class ApiClient {
  ApiClient._();

  static final Uri _base = Uri.parse(AppConfig.apiBaseUrl);

  static String get _token =>
      Supabase.instance.client.auth.currentSession?.accessToken ?? '';

  static Map<String, String> get _authHeaders => {
        'Authorization': 'Bearer $_token',
      };

  // ── JSON GET ──────────────────────────────────────────
  static Future<dynamic> get(String path) async {
    final res = await http.get(_base.resolve(path), headers: _authHeaders);
    return _handle(res);
  }

  // ── JSON POST ─────────────────────────────────────────
  static Future<dynamic> postJson(
      String path, Map<String, dynamic> body) async {
    final res = await http.post(
      _base.resolve(path),
      headers: {..._authHeaders, 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    return _handle(res);
  }

  // ── JSON PATCH ────────────────────────────────────────
  static Future<dynamic> patchJson(
      String path, Map<String, dynamic> body) async {
    final res = await http.patch(
      _base.resolve(path),
      headers: {..._authHeaders, 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    return _handle(res);
  }

  // ── DELETE ────────────────────────────────────────────
  static Future<dynamic> delete(String path) async {
    final res = await http.delete(_base.resolve(path), headers: _authHeaders);
    return _handle(res);
  }

  // ── Multipart POST ────────────────────────────────────
  static Future<dynamic> uploadMultipart(
    String path,
    List<http.MultipartFile> files, {
    Map<String, String>? fields,
  }) async {
    final req = http.MultipartRequest('POST', _base.resolve(path))
      ..headers.addAll(_authHeaders)
      ..files.addAll(files);
    if (fields != null) req.fields.addAll(fields);
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    return _handle(res);
  }

  // ── Response handler ──────────────────────────────────
  static dynamic _handle(http.Response res) {
    if (res.statusCode == 204) return <String, dynamic>{};
    if (res.body.isEmpty) return <String, dynamic>{};
    final body = jsonDecode(res.body);
    if (res.statusCode >= 400) {
      final detail = body is Map ? (body['detail'] ?? 'API error') : 'API error';
      throw ApiException(detail.toString(), res.statusCode);
    }
    return body;
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  const ApiException(this.message, this.statusCode);

  @override
  String toString() => 'ApiException($statusCode): $message';
}
