/// 유저 응답 DTO (GET /users/me, GET /users/{user_id})
/// 서버: uid, nickName, gmail, point, acceptCount, school, major
class UserResDto {
  final String uid;
  final String nickName;
  final String gmail;
  final int point;
  final int acceptCount;
  final String school;
  final String major;

  UserResDto({
    required this.uid,
    required this.nickName,
    required this.gmail,
    required this.point,
    required this.acceptCount,
    this.school = '',
    this.major = '',
  });

  factory UserResDto.fromJson(Map<String, dynamic> json) {
    return UserResDto(
      uid: (json['uid'] ?? json['userId'] ?? '').toString(),
      // nickName ↔ nickname 호환
      nickName: json['nickName'] ?? json['nickname'] ?? '',
      // gmail ↔ email 호환
      gmail: json['gmail'] ?? json['email'] ?? '',
      point: _parseInt(json['point']),
      acceptCount: _parseInt(json['acceptCount']),
      // school 필드
      school: (json['school'] ?? '').toString(),
      // major ↔ department 호환
      major: json['major'] ?? json['department'] ?? '',
    );
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'nickName': nickName,
      'gmail': gmail,
      'point': point,
      'acceptCount': acceptCount,
      'school': school,
      'major': major,
    };
  }
}

/// 유저 위치 응답 DTO (GET /users/me/location, GET /users/all/location)
/// 서버: uid, latitude, longitude
class UserLocationResDto {
  final String uid;
  final double latitude;
  final double longitude;
  final String? lastActiveAt;

  UserLocationResDto({
    required this.uid,
    required this.latitude,
    required this.longitude,
    this.lastActiveAt,
  });

  factory UserLocationResDto.fromJson(Map<String, dynamic> json) {
    return UserLocationResDto(
      uid: (json['uid'] ?? '').toString(),
      // [수정] 서버 필드명 latitude / longitude 우선, lat / lng 폴백
      latitude: ((json['latitude'] ?? json['lat'] ?? 0) as num).toDouble(),
      longitude: ((json['longitude'] ?? json['lng'] ?? 0) as num).toDouble(),
      lastActiveAt: json['lastActiveAt']?.toString(),
    );
  }

  /// [수정] 유효한 좌표 여부 (0,0이면 미설정으로 간주하여 제외)
  bool get hasValidLocation => latitude != 0.0 && longitude != 0.0;

  /// 활성 유저 여부 (현재시간 - lastActiveAt < 10초)
  bool get isActive {
    if (lastActiveAt == null) return false;
    try {
      final lastActive = DateTime.parse(lastActiveAt!);
      final now = DateTime.now();
      return now.difference(lastActive).inMilliseconds < 10000;
    } catch (_) {
      return false;
    }
  }
}

/// 유저 위치 업데이트 요청 DTO (PATCH /users/location)
/// 서버: latitude, longitude
class UserLocationUpdateReqDto {
  final double latitude;
  final double longitude;

  UserLocationUpdateReqDto({
    required this.latitude,
    required this.longitude,
  });

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}
