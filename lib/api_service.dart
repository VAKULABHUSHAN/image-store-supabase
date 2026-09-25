import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'main.dart';

class ApiService {
  static final ApiService instance = ApiService._internal();
  ApiService._internal();

  String get _baseUrl => backendApiUrl;

  Future<Map<String, String>> _getAuthHeaders() async {
    final token = supabase.auth.currentSession?.accessToken;
    return {
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  // 1. GET /health
  Future<bool> checkHealth() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/health')).timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // 2. GET /me
  Future<Map<String, dynamic>?> getMe() async {
    try {
      final headers = await _getAuthHeaders();
      final res = await http.get(Uri.parse('$_baseUrl/me'), headers: headers);
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print('getMe error: $e');
    }
    return null;
  }

  // 3. GET /voice/status
  Future<bool> getVoiceStatus() async {
    try {
      final headers = await _getAuthHeaders();
      final res = await http.get(Uri.parse('$_baseUrl/voice/status'), headers: headers);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['enrolled'] == true;
      }
    } catch (e) {
      print('getVoiceStatus error: $e');
    }
    return false;
  }

  // 4. POST /voice/enroll
  Future<bool> enrollVoice(File audioFile) async {
    try {
      final headers = await _getAuthHeaders();
      final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/voice/enroll'));
      request.headers.addAll(headers);
      request.files.add(await http.MultipartFile.fromPath('audio', audioFile.path));

      final streamedRes = await request.send();
      final res = await http.Response.fromStream(streamedRes);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['enrolled'] == true;
      }
    } catch (e) {
      print('enrollVoice error: $e');
    }
    return false;
  }

  // 5. POST /recognize
  Future<List<Map<String, dynamic>>> recognizeFace(File imageFile) async {
    try {
      final headers = await _getAuthHeaders();
      final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/recognize'));
      request.headers.addAll(headers);
      request.files.add(await http.MultipartFile.fromPath(
        'file',
        imageFile.path,
        contentType: MediaType('image', 'jpeg'),
      ));

      final streamedRes = await request.send();
      final res = await http.Response.fromStream(streamedRes);
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        return list.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      print('recognizeFace error: $e');
    }
    return [];
  }

  // 6. POST /session/start
  Future<Map<String, dynamic>?> startSession(String mode) async {
    try {
      final headers = await _getAuthHeaders();
      final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/session/start'));
      request.headers.addAll(headers);
      request.fields['mode'] = mode;

      final streamedRes = await request.send();
      final res = await http.Response.fromStream(streamedRes);
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print('startSession error: $e');
    }
    return null;
  }

  // 7. POST /session/{id}/end
  Future<Map<String, dynamic>?> endSession(
    String sessionId, {
    File? audioFile,
    String? personId,
    File? faceImageFile,
  }) async {
    try {
      final headers = await _getAuthHeaders();
      final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/session/$sessionId/end'));
      request.headers.addAll(headers);

      if (personId != null && personId.isNotEmpty) {
        request.fields['person_id'] = personId;
      }

      if (audioFile != null) {
        request.files.add(await http.MultipartFile.fromPath('audio', audioFile.path));
      }

      if (faceImageFile != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'face_image',
          faceImageFile.path,
          contentType: MediaType('image', 'jpeg'),
        ));
      }

      final streamedRes = await request.send();
      final res = await http.Response.fromStream(streamedRes);
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print('endSession error: $e');
    }
    return null;
  }

  // 8. GET /session/{id} (Poll session result)
  Future<Map<String, dynamic>?> getSession(String sessionId, {bool includeFace = false}) async {
    try {
      final headers = await _getAuthHeaders();
      final uri = Uri.parse('$_baseUrl/session/$sessionId?include_face=$includeFace');
      final res = await http.get(uri, headers: headers);
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print('getSession error: $e');
    }
    return null;
  }

  // 9. POST /person/finalize (Name person after session)
  Future<Map<String, dynamic>?> finalizePerson({
    required String sessionId,
    String? name,
    String? relationship,
    String? personId,
    File? faceImageFile,
    bool useSessionFace = false,
  }) async {
    try {
      final headers = await _getAuthHeaders();
      final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/person/finalize'));
      request.headers.addAll(headers);

      request.fields['session_id'] = sessionId;
      if (name != null) request.fields['name'] = name;
      if (relationship != null) request.fields['relationship'] = relationship;
      if (personId != null) request.fields['person_id'] = personId;
      if (useSessionFace) request.fields['use_session_face'] = 'true';

      if (faceImageFile != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'face_image',
          faceImageFile.path,
          contentType: MediaType('image', 'jpeg'),
        ));
      }

      final streamedRes = await request.send();
      final res = await http.Response.fromStream(streamedRes);
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print('finalizePerson error: $e');
    }
    return null;
  }

  // 10. GET /people
  Future<List<Map<String, dynamic>>> getPeople() async {
    try {
      final headers = await _getAuthHeaders();
      final res = await http.get(Uri.parse('$_baseUrl/people'), headers: headers);
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        return list.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      print('getPeople error: $e');
    }
    return [];
  }

  // 11. GET /sessions
  Future<List<Map<String, dynamic>>> getSessions() async {
    try {
      final headers = await _getAuthHeaders();
      final res = await http.get(Uri.parse('$_baseUrl/sessions'), headers: headers);
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        return list.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      print('getSessions error: $e');
    }
    return [];
  }
}
