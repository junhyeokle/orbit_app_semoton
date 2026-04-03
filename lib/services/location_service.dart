import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'api_service.dart';
import '../models/user_model.dart';
import '../models/post_model.dart';
import '../services/campus_data.dart';

class LocationService {
  final ApiService _api = ApiService();
  Position? _lastPosition;

  Position? get lastPosition => _lastPosition;

  /// 위치 권한 요청 및 현재 위치 가져오기 (1회)
  Future<Position?> getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      _lastPosition = position;
      return position;
    } catch (e) {
      return null;
    }
  }

  /// 서버에 위치 동기화 (PATCH /users/location) - 1회
  Future<bool> syncLocationToServer() async {
    final position = await getCurrentPosition();
    if (position == null) return false;

    return await _api.syncLocation(UserLocationUpdateReqDto(
      latitude: position.latitude,
      longitude: position.longitude,
    ));
  }

  // [삭제] startPeriodicSync / stopPeriodicSync 제거
  // → 새로고침 버튼 클릭 시 1회만 호출

  /// 모든 유저 위치 가져오기 (GET /users/all/location) - 1회
  Future<List<UserLocationResDto>> getAllUserLocations() async {
    return await _api.getAllUserLocations();
  }

  /// 활성 유저만 필터링
  Future<List<UserLocationResDto>> getActiveUserLocations() async {
    final all = await getAllUserLocations();
    return all.where((u) => u.isActive).toList();
  }

  /// 건물별 활성 유저 수 계산
  Map<String, int> calculateUserCountByBuilding(
      List<UserLocationResDto> activeUsers) {
    final Map<String, int> counts = {};

    for (final building in CampusDataService.buildings) {
      int count = 0;
      for (final user in activeUsers) {
        if (!user.hasValidLocation) continue;

        final distance = Geolocator.distanceBetween(
          user.latitude,
          user.longitude,
          building.latitude,
          building.longitude,
        );
        if (distance <= building.radius) {
          count++;
        }
      }
      counts[building.name] = count;
    }

    return counts;
  }

  /// 건물별 게시물 수 계산
  Map<String, int> calculatePostCountByBuilding(List<PostResDto> posts) {
    final Map<String, int> counts = {};

    for (final post in posts) {
      if (post.latitude == 0 && post.longitude == 0) continue;

      String? closestBuildingName;
      double minDist = double.infinity;

      for (final building in CampusDataService.buildings) {
        final dist = CampusDataService.calculateDistance(
          post.latitude,
          post.longitude,
          building.latitude,
          building.longitude,
        );
        if (dist < minDist) {
          minDist = dist;
          closestBuildingName = building.name;
        }
      }

      if (closestBuildingName != null && minDist < 500) {
        counts[closestBuildingName] =
            (counts[closestBuildingName] ?? 0) + 1;
      }
    }

    return counts;
  }

  /// 본인 위치 가져오기
  Future<UserLocationResDto?> getMyLocation() async {
    return await _api.getMyLocation();
  }

  void dispose() {
    // [수정] 타이머 없으므로 정리할 것 없음
  }
}
