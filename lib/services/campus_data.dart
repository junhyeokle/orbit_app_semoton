import 'dart:math';

class Building {
  final String name;
  final String key; // API에서 사용하는 영문 key
  final double latitude;
  final double longitude;
  final double radius; // 미터 단위

  const Building({
    required this.name,
    required this.key,
    required this.latitude,
    required this.longitude,
    this.radius = 50.0,
  });
}

class CampusDataService {
  /// 경희대 국제캠퍼스 15개 건물 (정확한 좌표)
  static const List<Building> buildings = [
    Building(name: '학생회관', key: 'studentCenter', latitude: 37.2419772, longitude: 127.0799826, radius: 40),
    Building(name: '선승관', key: 'seonseung', latitude: 37.2427982, longitude: 127.0800721, radius: 50),
    Building(name: '사회과학대학관', key: 'socialScience', latitude: 37.2421219, longitude: 127.0812392, radius: 40),
    Building(name: '생명과학대학', key: 'lifeScience', latitude: 37.2428935, longitude: 127.0812315, radius: 50),
    Building(name: '국제대학', key: 'international', latitude: 37.2398083, longitude: 127.0811889, radius: 40),
    Building(name: '전자정보대학', key: 'elecNinfo', latitude: 37.2395419, longitude: 127.0834292, radius: 80),
    Building(name: '예술디자인대학', key: 'artDesign', latitude: 37.2417578, longitude: 127.0844311, radius: 60),
    Building(name: '체육대학관', key: 'sports', latitude: 37.2443222, longitude: 127.0803514, radius: 70),
    Building(name: '우정원', key: 'woojungwon', latitude: 37.2459834, longitude: 127.0769997, radius: 60),
    Building(name: '공과대학', key: 'engineering', latitude: 37.2462951, longitude: 127.0804748, radius: 100),
    Building(name: '외국어대학', key: 'foreignLang', latitude: 37.2452270, longitude: 127.0777406, radius: 40),
    Building(name: '멀티미디어관', key: 'multimedia', latitude: 37.2444180, longitude: 127.0764555, radius: 50),
    Building(name: '제2기숙사(여)', key: 'dorm2F', latitude: 37.2436384, longitude: 127.0766989, radius: 30),
    Building(name: '제2기숙사(남)', key: 'dorm2M', latitude: 37.2426196, longitude: 127.0771254, radius: 40),
    Building(name: '중앙도서관', key: 'library', latitude: 37.2408329, longitude: 127.0795880, radius: 70),
  ];

  /// 건물 이름으로 Building 찾기
  static Building? findByName(String name) {
    try {
      return buildings.firstWhere((b) => b.name == name);
    } catch (_) {
      return null;
    }
  }

  /// 건물 key로 Building 찾기
  static Building? findByKey(String key) {
    try {
      return buildings.firstWhere((b) => b.key == key);
    } catch (_) {
      return null;
    }
  }

  final Map<String, int> _userCounts = {};
  final Map<String, int> _postCounts = {};
  final _random = Random();

  CampusDataService() {
    refresh();
  }

  void refresh() {
    for (final b in buildings) {
      _userCounts[b.name] = _random.nextInt(20) + 1;
      _postCounts[b.name] = _random.nextInt(10) + 1;
    }
  }

  Map<String, int> getUserCounts() => Map.unmodifiable(_userCounts);
  Map<String, int> getPostCounts() => Map.unmodifiable(_postCounts);

  int getCount(String buildingName, {bool isUser = true}) {
    return isUser
        ? (_userCounts[buildingName] ?? 0)
        : (_postCounts[buildingName] ?? 0);
  }

  /// Haversine 거리 계산 (미터 단위)
  static double calculateDistance(
    double lat1, double lon1,
    double lat2, double lon2,
  ) {
    const double earthRadius = 6371000; // 미터
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  static double _toRadians(double degrees) => degrees * pi / 180;
}
