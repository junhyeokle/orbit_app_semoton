import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';

class ApiService {
  static const String baseUrl = 'http://52.79.112.27:8080';

  /// Firebase ID Token을 가져와서 Bearer 헤더 생성
  Future<Map<String, String>> _authHeaders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('로그인이 필요합니다.');
    final token = await user.getIdToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ──────────────── Auth ────────────────

  /// 로그인: Firebase 토큰을 서버에 전달하여 등록/검증
  Future<UserResDto?> login() async {
    try {
      final headers = await _authHeaders();
      debugPrint('[API] POST /auth/login');
      debugPrint('[API] Token: ${headers['Authorization']?.substring(0, 30)}...');

      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: headers,
      );

      debugPrint('[API] login status: ${response.statusCode}');
      debugPrint('[API] login body: ${utf8.decode(response.bodyBytes)}');

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return UserResDto.fromJson(data);
      }
      return null;
    } catch (e) {
      debugPrint('[API] login error: $e');
      return null;
    }
  }

  // ──────────────── Posts ────────────────

  /// 현재 위치 가져오기 (실패 시 기본값 0,0)
  Future<Position> _getCurrentPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[API] 위치 서비스 비활성화 → 기본값 사용');
        return Position(
          latitude: 0,
          longitude: 0,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('[API] 위치 권한 거부 → 기본값 사용');
          return Position(
            latitude: 0,
            longitude: 0,
            timestamp: DateTime.now(),
            accuracy: 0,
            altitude: 0,
            altitudeAccuracy: 0,
            heading: 0,
            headingAccuracy: 0,
            speed: 0,
            speedAccuracy: 0,
          );
        }
      }
      if (permission == LocationPermission.deniedForever) {
        debugPrint('[API] 위치 권한 영구 거부 → 기본값 사용');
        return Position(
          latitude: 0,
          longitude: 0,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (e) {
      debugPrint('[API] 위치 가져오기 실패: $e → 기본값 사용');
      return Position(
        latitude: 0,
        longitude: 0,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
    }
  }

  /// 게시물 전체 가져오기 (GET /posts/all?userLat=...&userLng=...&sortBy=...)
  Future<List<PostResDto>> getAllPosts({String sortBy = 'latest'}) async {
    try {
      final headers = await _authHeaders();

      // 현재 위치 가져오기
      final position = await _getCurrentPosition();
      final userLat = position.latitude;
      final userLng = position.longitude;

      final url = '$baseUrl/posts/all?lat=$userLat&lng=$userLng&sortBy=$sortBy';
      debugPrint('[API] GET $url');

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      debugPrint('[API] getAllPosts status: ${response.statusCode}');
      final responseBody = utf8.decode(response.bodyBytes);
      debugPrint('[API] getAllPosts body: ${responseBody.length > 500 ? responseBody.substring(0, 500) : responseBody}');

      if (response.statusCode == 200) {
        final decoded = json.decode(responseBody);

        // 응답이 List인 경우
        if (decoded is List) {
          final posts = decoded.map((e) => PostResDto.fromJson(e)).toList();
          debugPrint('[API] getAllPosts parsed: ${posts.length}개');
          return posts;
        }

        // 응답이 Map인 경우 (페이지네이션: { content: [...] })
        if (decoded is Map) {
          final content = decoded['content'] ?? decoded['posts'] ?? decoded['data'];
          if (content is List) {
            final posts = content.map((e) => PostResDto.fromJson(e)).toList();
            debugPrint('[API] getAllPosts parsed (from map): ${posts.length}개');
            return posts;
          }
        }

        debugPrint('[API] getAllPosts: unexpected response format');
        return [];
      }

      debugPrint('[API] getAllPosts failed: ${response.statusCode}');
      return [];
    } catch (e) {
      debugPrint('[API] getAllPosts error: $e');
      return [];
    }
  }

  /// 게시물 상세 조회 (GET /posts/{postId})
  Future<PostResDto?> getPostDetail(String postId) async {
    try {
      final headers = await _authHeaders();
      debugPrint('[API] GET /posts/$postId');

      final response = await http.get(
        Uri.parse('$baseUrl/posts/$postId'),
        headers: headers,
      );

      debugPrint('[API] getPostDetail status: ${response.statusCode}');
      debugPrint('[API] getPostDetail body: ${utf8.decode(response.bodyBytes)}');

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return PostResDto.fromJson(data);
      }
      return null;
    } catch (e) {
      debugPrint('[API] getPostDetail error: $e');
      return null;
    }
  }

  /// 게시물 작성 (POST /posts/create)
  Future<String?> createPost(PostCreateReqDto dto) async {
    try {
      final headers = await _authHeaders();
      final body = json.encode(dto.toJson());
      debugPrint('[API] POST /posts/create body: $body');

      final response = await http.post(
        Uri.parse('$baseUrl/posts/create'),
        headers: headers,
        body: body,
      );

      debugPrint('[API] createPost status: ${response.statusCode}');
      debugPrint('[API] createPost body: ${utf8.decode(response.bodyBytes)}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseBody = utf8.decode(response.bodyBytes);
        if (responseBody.isEmpty) return 'created';

        try {
          final data = json.decode(responseBody);
          // 응답이 Map인 경우 postId 또는 id 추출
          if (data is Map) {
            return (data['postId'] ?? data['id'] ?? 'created').toString();
          }
          // 응답이 String인 경우 그대로 반환
          return data.toString();
        } catch (_) {
          return responseBody;
        }
      }
      debugPrint('[API] createPost failed: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('[API] createPost error: $e');
      return null;
    }
  }

  /// 게시물 수락 (POST /posts/{postId}/accept)
  Future<bool> acceptPost(String postId) async {
    try {
      final headers = await _authHeaders();
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final body = json.encode({'acceptingUserId': uid});
      debugPrint('[API] POST /posts/$postId/accept body: $body');

      final response = await http.post(
        Uri.parse('$baseUrl/posts/$postId/accept'),
        headers: headers,
        body: body,
      );

      debugPrint('[API] acceptPost status: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[API] acceptPost error: $e');
      return false;
    }
  }

  // [추가] 게시물 완료 처리 (POST /posts/{postId}/complete)
  Future<bool> completePost(String postId) async {
    try {
      final headers = await _authHeaders();
      debugPrint('[API] POST /posts/$postId/complete');

      final response = await http.post(
        Uri.parse('$baseUrl/posts/$postId/complete'),
        headers: headers,
      );

      debugPrint('[API] completePost status: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[API] completePost error: $e');
      return false;
    }
  }

  /// AI 분석 결과 조회 (GET /posts/{postId}/ai)
  Future<Map<String, dynamic>?> getAiResult(String postId) async {
    try {
      final headers = await _authHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/posts/$postId/ai'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ──────────────── Users ────────────────

  /// 본인 정보 조회 (GET /users/me)
  Future<UserResDto?> getMyProfile() async {
    try {
      final headers = await _authHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/users/me'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return UserResDto.fromJson(data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// 유저 조회 (GET /users/{user_id})
  Future<UserResDto?> getUserById(String userId) async {
    try {
      final headers = await _authHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/users/$userId'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return UserResDto.fromJson(data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// 모든 유저 목록 (GET /users)
  Future<List<UserResDto>> getAllUsers() async {
    try {
      final headers = await _authHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/users'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final decoded = json.decode(utf8.decode(response.bodyBytes));
        if (decoded is List) {
          return decoded.map((e) => UserResDto.fromJson(e)).toList();
        }
        if (decoded is Map && decoded['content'] is List) {
          return (decoded['content'] as List)
              .map((e) => UserResDto.fromJson(e))
              .toList();
        }
        return [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // ──────────────── Location ────────────────

  /// 유저 위치 정보 동기화 (PATCH /users/location)
  Future<bool> syncLocation(UserLocationUpdateReqDto dto) async {
    try {
      final headers = await _authHeaders();
      final response = await http.patch(
        Uri.parse('$baseUrl/users/location'),
        headers: headers,
        body: json.encode(dto.toJson()),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// 본인 위치정보 조회 (GET /users/me/location)
  Future<UserLocationResDto?> getMyLocation() async {
    try {
      final headers = await _authHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/users/me/location'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return UserLocationResDto.fromJson(data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// 모든 유저 위치 정보 조회 (GET /users/all/location)
  Future<List<UserLocationResDto>> getAllUserLocations() async {
    try {
      final headers = await _authHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/users/all/location'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final List<dynamic> list = json.decode(utf8.decode(response.bodyBytes));
        return list.map((e) => UserLocationResDto.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}
