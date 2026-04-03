/// 게시물 생성 요청 DTO (POST /posts/create)
/// 서버: userId, title, content, latitude, longitude, rewardPoint
class PostCreateReqDto {
  final String userId;
  final String title;
  final String content;
  final double latitude;
  final double longitude;
  final int rewardPoint;

  PostCreateReqDto({
    required this.userId,
    required this.title,
    required this.content,
    required this.latitude,
    required this.longitude,
    required this.rewardPoint,
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'title': title,
      'content': content,
      'latitude': latitude,
      'longitude': longitude,
      'rewardPoint': rewardPoint,
    };
  }
}

/// 게시물 응답 DTO (GET /posts/all, GET /posts/{postId})
/// 서버: postId, userId, title, content, createdAt(long),
///       isAccept, accepted_userId, latitude, longitude, rewardPoint
class PostResDto {
  final String postId;
  final String userId;
  final String title;
  final String content;
  final int createdAt; // epoch millis
  final bool isAccept;
  final String? acceptedUserId;
  final double latitude;
  final double longitude;
  final int rewardPoint;
  final bool isCompleted; // [추가] 완료(종료) 상태

  PostResDto({
    required this.postId,
    required this.userId,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.isAccept,
    this.acceptedUserId,
    required this.latitude,
    required this.longitude,
    this.rewardPoint = 0,
    this.isCompleted = false, // [추가]
  });

  /// point getter — 기존 코드 호환용 (rewardPoint를 반환)
  int get point => rewardPoint;

  factory PostResDto.fromJson(Map<String, dynamic> json) {
    return PostResDto(
      postId: (json['postId'] ?? json['id'] ?? '').toString(),
      userId: (json['userId'] ?? '').toString(),
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      createdAt: _parseCreatedAt(json['createdAt'] ?? json['isCreated']),
      isAccept: json['isAccept'] ?? json['accept'] ?? json['accepted'] ?? false,
      acceptedUserId:
          (json['accepted_userId'] ?? json['acceptedUserId'])?.toString(),
      latitude: (json['latitude'] ?? json['lat'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? json['lng'] ?? 0).toDouble(),
      rewardPoint: _parseInt(json['rewardPoint'] ?? json['point']),
      isCompleted: json['completed'] ?? json['isCompleted'] ?? false, // [추가]
    );
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  /// createdAt을 다양한 형식에서 epoch millis로 파싱
  static int _parseCreatedAt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
      try {
        return DateTime.parse(value).millisecondsSinceEpoch;
      } catch (_) {}
    }
    if (value is Map) {
      final seconds = value['_seconds'] ?? value['seconds'] ?? 0;
      return (seconds as num).toInt() * 1000;
    }
    return 0;
  }

  /// createdAt을 DateTime으로 변환
  DateTime get createdAtDateTime =>
      DateTime.fromMillisecondsSinceEpoch(createdAt);

  /// 표시용 시간 문자열
  String get createdAtDisplay {
    if (createdAt == 0) return '';
    try {
      final created = createdAtDateTime;
      final now = DateTime.now();
      final diff = now.difference(created);

      if (diff.inMinutes < 1) return '방금 전';
      if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
      if (diff.inHours < 24) return '${diff.inHours}시간 전';
      if (diff.inDays < 7) return '${diff.inDays}일 전';
      return '${created.month}월 ${created.day}일';
    } catch (_) {
      return '';
    }
  }
}

/// 게시물 수락 요청 DTO (POST /posts/{postId}/accept)
class PostAcceptReqDto {
  final String acceptingUserId;

  PostAcceptReqDto({required this.acceptingUserId});

  Map<String, dynamic> toJson() {
    return {
      'acceptingUserId': acceptingUserId,
    };
  }
}
