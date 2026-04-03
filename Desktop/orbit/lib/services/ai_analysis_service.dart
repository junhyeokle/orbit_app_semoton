import 'dart:math';
import 'package:geolocator/geolocator.dart';
import '../models/post_model.dart';
import 'campus_data.dart';

/// AI 분석 결과 모델
class AiAnalysisResult {
  final String object;        // 물건
  final String fromLocation;  // 출발 위치
  final String toLocation;    // 도착 위치
  final String urgency;       // 긴급도
  final String distance;      // 거리 텍스트
  final double distanceMeters; // 거리 (미터)
  final int score;            // AI 점수
  final String difficulty;    // 난이도
  final String advice;        // AI 조언

  AiAnalysisResult({
    required this.object,
    required this.fromLocation,
    required this.toLocation,
    required this.urgency,
    required this.distance,
    required this.distanceMeters,
    required this.score,
    required this.difficulty,
    required this.advice,
  });
}

/// AI 분석 서비스 — 게시물을 분석하여 점수/조언 생성
class AiAnalysisService {

  /// 게시물 데이터에서 핵심 정보 추출 + 점수 계산 + 조언 생성
  AiAnalysisResult enhanceAiResult(PostResDto post, {double? userLat, double? userLng}) {
    // ─── 1. 핵심 정보 추출 ───
    final fullText = '${post.title} ${post.content}';

    final category = _extractCategory(fullText);
    final object = _extractObject(fullText);
    final fromLocation = _extractFromLocation(fullText, post);
    final toLocation = _extractToLocation(fullText);
    final urgency = _extractUrgency(fullText);

    // ─── 2. 거리 계산 ───
    final distResult = calculateDistance(post, userLat: userLat, userLng: userLng);
    final distanceMeters = distResult['meters'] as double;
    final distanceText = distResult['text'] as String;

    // ─── 3. 점수 계산 ───
    final score = calculateScore(
      category: category,
      object: object,
      fromLocation: fromLocation,
      toLocation: toLocation,
      urgency: urgency,
      distanceMeters: distanceMeters,
      rewardPoint: post.rewardPoint,
    );

    // ─── 4. 난이도 판정 ───
    final difficulty = _getDifficulty(score);

    // ─── 5. 조언 생성 ───
    final advice = generateAdvice(
      score: score,
      distanceMeters: distanceMeters,
      object: object,
      category: category,
      rewardPoint: post.rewardPoint,
    );

    return AiAnalysisResult(
      object: object,
      fromLocation: fromLocation,
      toLocation: toLocation,
      urgency: urgency,
      distance: distanceText,
      distanceMeters: distanceMeters,
      score: score.clamp(0, 100),
      difficulty: difficulty,
      advice: advice,
    );
  }

  // ═══════════════════════════════════════
  // 정보 추출 함수들
  // ═══════════════════════════════════════

  String _extractCategory(String text) {
    if (text.contains('배달') || text.contains('전달') || text.contains('가져다')) return '배달';
    if (text.contains('대여') || text.contains('빌려')) return '대여';
    if (text.contains('심부름')) return '심부름';
    if (text.contains('운반') || text.contains('옮겨')) return '운반';
    return '기타';
  }

  String _extractObject(String text) {
    final objects = {
      '노트북': '노트북', '맥북': '노트북', '랩탑': '노트북',
      '휴대폰': '휴대폰', '핸드폰': '휴대폰', '폰': '휴대폰', '스마트폰': '휴대폰',
      '이어폰': '이어폰', '에어팟': '이어폰', '이어버드': '이어폰',
      '충전기': '충전기', '충전': '충전기',
      '책': '책', '교재': '책', '교과서': '책', '필기': '책',
      '우산': '우산',
      '음식': '음식', '커피': '음식', '도시락': '음식', '음료': '음식', '밥': '음식',
      '택배': '택배', '배송': '택배',
      '서류': '서류', '과제': '서류', '문서': '서류', '출력': '서류', '프린트': '서류',
    };

    for (final entry in objects.entries) {
      if (text.contains(entry.key)) return entry.value;
    }
    return '기타 물건';
  }

  String _extractFromLocation(String text, PostResDto post) {
    // 게시물 좌표 기반으로 가장 가까운 건물 찾기
    final nearest = _findNearestBuilding(post.latitude, post.longitude);
    if (nearest != null) return nearest;

    // 텍스트에서 건물명 추출
    for (final b in CampusDataService.buildings) {
      if (text.contains(b.name)) return b.name;
    }
    return '캠퍼스 내';
  }

  String _extractToLocation(String text) {
    final keywords = ['까지', '으로', '에서', '→', '->', '도착'];
    for (final b in CampusDataService.buildings) {
      for (final kw in keywords) {
        if (text.contains('${b.name}$kw') || text.contains('${b.name} $kw')) {
          return b.name;
        }
      }
    }
    // 건물명 두 번째 등장 찾기
    final foundBuildings = <String>[];
    for (final b in CampusDataService.buildings) {
      if (text.contains(b.name)) foundBuildings.add(b.name);
    }
    if (foundBuildings.length >= 2) return foundBuildings[1];
    return '주변 건물';
  }

  String _extractUrgency(String text) {
    final urgentKeywords = ['급해', '급합', '빨리', '긴급', '지금', '바로', '즉시', '당장', 'ASAP', '제발'];
    for (final kw in urgentKeywords) {
      if (text.contains(kw)) return '긴급';
    }
    return '보통';
  }

  String? _findNearestBuilding(double lat, double lng) {
    if (lat == 0 && lng == 0) return null;

    String? nearest;
    double minDist = double.infinity;

    for (final b in CampusDataService.buildings) {
      final dist = Geolocator.distanceBetween(lat, lng, b.latitude, b.longitude);
      if (dist < minDist) {
        minDist = dist;
        nearest = b.name;
      }
    }
    return (minDist < 500) ? nearest : null;
  }

  // ═══════════════════════════════════════
  // 거리 계산
  // ═══════════════════════════════════════

  Map<String, dynamic> calculateDistance(PostResDto post, {double? userLat, double? userLng}) {
    if (userLat == null || userLng == null || post.latitude == 0) {
      // 사용자 위치 없으면 랜덤 추정
      final estimated = 50 + Random().nextInt(300);
      return {'meters': estimated.toDouble(), 'text': '약 ${estimated}m'};
    }
    final meters = Geolocator.distanceBetween(
      userLat, userLng, post.latitude, post.longitude,
    );
    final rounded = meters.round();
    final text = rounded >= 1000
        ? '${(meters / 1000).toStringAsFixed(1)}km'
        : '${rounded}m';
    return {'meters': meters, 'text': text};
  }

  // ═══════════════════════════════════════
  // 점수 계산
  // ═══════════════════════════════════════

  int calculateScore({
    required String category,
    required String object,
    required String fromLocation,
    required String toLocation,
    required String urgency,
    required double distanceMeters,
    required int rewardPoint,
  }) {
    int score = 0;

    // [1] 카테고리 기본 점수
    if (category.isNotEmpty && category != '기타') score += 30;

    // [2] 출발 위치 정보 존재
    if (fromLocation.isNotEmpty && fromLocation != '캠퍼스 내') score += 15;

    // [3] 도착 위치 정보 존재
    if (toLocation.isNotEmpty && toLocation != '주변 건물') score += 15;

    // [4] 물건 정보 존재
    if (object.isNotEmpty && object != '기타 물건') score += 20;

    // [5] 긴급도
    if (urgency == '긴급') {
      score += 20;
    } else {
      score += 10;
    }

    // [6] 거리 점수 — 가까울수록 높음
    if (distanceMeters <= 100) {
      score += 30;
    } else if (distanceMeters <= 300) {
      score += 20;
    } else if (distanceMeters <= 700) {
      score += 10;
    }

    // [7] 부담도/패널티 — 카테고리
    if (category == '대여') score -= 10;
    if (category == '심부름') score -= 15;

    // [8] 물건 패널티 — 고가 물건
    if (object == '충전기' || object == '책') {
      score -= 0;
    } else if (object == '이어폰') {
      score -= 10;
    } else if (object == '노트북' || object == '휴대폰') {
      score -= 25;
    }

    // [9] 보상 보정
    if (rewardPoint >= 10000) {
      score += 20;
    } else if (rewardPoint >= 5000) {
      score += 10;
    }

    return score.clamp(0, 100);
  }

  // ═══════════════════════════════════════
  // 난이도 판정
  // ═══════════════════════════════════════

  String _getDifficulty(int score) {
    if (score >= 80) return '쉬움';
    if (score >= 60) return '보통';
    if (score >= 40) return '다소 어려움';
    return '어려움';
  }

  // ═══════════════════════════════════════
  // 조언 생성
  // ═══════════════════════════════════════

  String generateAdvice({
    required int score,
    required double distanceMeters,
    required String object,
    required String category,
    required int rewardPoint,
  }) {
    // 고가 물건 주의
    if (object == '노트북' || object == '휴대폰') {
      if (category == '대여') {
        return '고가 물건을 대여해야 하므로 신중하게 판단하는 것이 좋습니다. 분실 위험에 대비해 상대방과 충분히 소통한 후 진행하세요.';
      }
      return '고가 물건이 포함된 요청입니다. 안전하게 전달할 수 있는 상황인지 먼저 확인해보세요.';
    }

    // 높은 점수 (80+)
    if (score >= 80) {
      if (distanceMeters <= 100) {
        return '거리도 가깝고 부담이 적어 가볍게 수행해볼 만합니다. 이동 시간이 거의 없어 빠르게 완료할 수 있어요.';
      }
      return '전반적으로 수행하기 좋은 조건입니다. 보상도 적절하고 난이도가 낮아 추천드립니다.';
    }

    // 중간 점수 (60~79)
    if (score >= 60) {
      if (rewardPoint >= 5000) {
        return '거리는 조금 있지만 보상이 충분해 시도해볼 가치가 있습니다. 이동 경로를 미리 확인해보세요.';
      }
      return '무난하게 수행할 수 있는 요청입니다. 시간 여유가 있다면 도전해보세요.';
    }

    // 낮은 점수 (40~59)
    if (score >= 40) {
      if (rewardPoint >= 5000) {
        return '난이도가 있지만 보상이 괜찮습니다. 시간과 상황을 고려해서 결정하세요.';
      }
      return '노력 대비 보상이 다소 적을 수 있습니다. 여유가 있을 때 수행하는 것을 권장합니다.';
    }

    // 매우 낮은 점수
    return '노력 대비 보상이 적어 추천하지 않습니다. 다른 요청을 먼저 살펴보시는 것이 좋겠습니다.';
  }
}
