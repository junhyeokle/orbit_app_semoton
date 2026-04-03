import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/campus_data.dart';
import '../services/post_service.dart';
import '../models/post_model.dart';
import '../widgets/bottom_nav_bar.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  final PostService _postService = PostService();

  String _mode = 'users'; // 'users' or 'posts'
  final _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  bool _showSearchResults = false;

  // [수정] 새로고침 기반 데이터
  Map<String, int> _userCounts = {};
  Map<String, int> _postCounts = {};
  bool _isDataLoaded = false;
  bool _isRefreshing = false;

  // 경희대 국제캠퍼스 중심
  static const _center = LatLng(37.2430, 127.0800);

  @override
  void initState() {
    super.initState();
    _refreshAll(); // 최초 1회 자동 실행
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  /// [수정] 통합 새로고침: 위치 저장 + 유저 목록 + 게시물 1회 조회
  Future<void> _refreshAll() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);

    try {
      double? userLat;
      double? userLng;

      // 1️⃣ 현재 사용자 위치 가져오기 (1회)
      try {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          ).timeout(const Duration(seconds: 5));
          userLat = position.latitude;
          userLng = position.longitude;

          // 2️⃣ 내 위치 Firestore 저장 (1회)
          final userId = FirebaseAuth.instance.currentUser?.uid;
          if (userId != null) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .set({
              'lat': userLat,
              'lng': userLng,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          }
        }
      } catch (e) {
        debugPrint('[MAP] 위치 가져오기 실패: $e');
      }

      // 3️⃣ 전체 유저 위치 가져오기 (Firestore 1회)
      final usersSnapshot =
          await FirebaseFirestore.instance.collection('users').get();
      final users = usersSnapshot.docs;

      // 4️⃣ 게시물 목록 가져오기 (서버 API, 1회)
      final posts = await _postService.getAllPosts();

      // 5️⃣ 건물별 유저 수 계산
      final userCounts = _calculateUsersPerBuilding(users);

      // 6️⃣ 건물별 게시물 수 계산
      final postCounts = _calculatePostsPerBuilding(posts);

      if (mounted) {
        setState(() {
          _userCounts = userCounts;
          _postCounts = postCounts;
          _isDataLoaded = true;
          _isRefreshing = false;
        });
      }
    } catch (e) {
      debugPrint('[MAP] refreshAll 실패: $e');
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  /// [추가] Haversine 거리 계산 (m 단위)
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000.0;
    final dLat = (lat2 - lat1) * (pi / 180);
    final dLon = (lon2 - lon1) * (pi / 180);
    final a = (sin(dLat / 2) * sin(dLat / 2)) +
        cos(lat1 * (pi / 180)) *
            cos(lat2 * (pi / 180)) *
            (sin(dLon / 2) * sin(dLon / 2));
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  /// [추가] 건물별 유저 수 계산 (Firestore users 기반)
  Map<String, int> _calculateUsersPerBuilding(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> users) {
    final Map<String, int> result = {};

    for (final building in CampusDataService.buildings) {
      int count = 0;
      for (final userDoc in users) {
        final data = userDoc.data();
        final lat = (data['lat'] as num?)?.toDouble();
        final lng = (data['lng'] as num?)?.toDouble();
        if (lat == null || lng == null || (lat == 0 && lng == 0)) continue;

        final distance = _calculateDistance(
          building.latitude, building.longitude, lat, lng,
        );
        if (distance <= building.radius) {
          count++;
        }
      }
      result[building.name] = count;
    }
    return result;
  }

  /// [추가] 건물별 게시물 수 계산
  Map<String, int> _calculatePostsPerBuilding(List<PostResDto> posts) {
    final Map<String, int> counts = {};

    for (final post in posts) {
      if (post.latitude == 0 && post.longitude == 0) continue;

      String? closestBuildingName;
      double minDist = double.infinity;

      for (final building in CampusDataService.buildings) {
        final dist = _calculateDistance(
          post.latitude, post.longitude,
          building.latitude, building.longitude,
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

  /// 검색 결과 필터링
  List<Building> get _filteredBuildings {
    if (_searchQuery.isEmpty) return [];
    return CampusDataService.buildings
        .where((b) => b.name.contains(_searchQuery))
        .toList();
  }

  /// 건물로 카메라 이동
  void _moveCameraToBuilding(Building building) {
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(building.latitude, building.longitude),
        17.5,
      ),
    );
    setState(() {
      _searchQuery = '';
      _searchController.clear();
      _showSearchResults = false;
    });
    _searchFocusNode.unfocus();
    _onBuildingTap(building);
  }

  /// 모든 건물에 Circle 표시 (0이어도 표시)
  Set<Circle> _buildCircles() {
    final counts = _mode == 'users' ? _userCounts : _postCounts;
    final maxCount = counts.values.isEmpty
        ? 1
        : counts.values.fold<int>(1, (a, b) => a > b ? a : b);
    final circles = <Circle>{};

    for (final building in CampusDataService.buildings) {
      final count = counts[building.name] ?? 0;

      final baseColor = _mode == 'users'
          ? const Color(0xFF53CDC3)
          : const Color(0xFFFF9800);

      if (count == 0) {
        // 0이어도 작은 기본 원 표시
        circles.add(Circle(
          circleId: CircleId(building.name),
          center: LatLng(building.latitude, building.longitude),
          radius: 18.0,
          fillColor: baseColor.withOpacity(0.15),
          strokeColor: baseColor.withOpacity(0.4),
          strokeWidth: 1,
        ));
      } else {
        final ratio = count / maxCount;
        final radius = 30.0 + (ratio * 50.0);

        circles.add(Circle(
          circleId: CircleId(building.name),
          center: LatLng(building.latitude, building.longitude),
          radius: radius,
          fillColor: baseColor.withOpacity(0.3 + ratio * 0.4),
          strokeColor: baseColor,
          strokeWidth: 2,
        ));
      }
    }

    return circles;
  }

  /// 모든 건물에 마커 표시 (0이어도 표시)
  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    for (final building in CampusDataService.buildings) {
      final userCount = _userCounts[building.name] ?? 0;
      final postCount = _postCounts[building.name] ?? 0;

      markers.add(Marker(
        markerId: MarkerId(building.name),
        position: LatLng(building.latitude, building.longitude),
        onTap: () => _onBuildingTap(building),
        infoWindow: InfoWindow(
          title: building.name,
          snippet: '접속 ${userCount}명 · 게시글 ${postCount}개',
        ),
      ));
    }

    return markers;
  }

  void _onBuildingTap(Building building) {
    final userCount = _userCounts[building.name] ?? 0;
    final postCount = _postCounts[building.name] ?? 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF53CDC3).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.location_city,
                      color: Color(0xFF53CDC3),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      building.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _buildInfoCard(
                    Icons.person,
                    '접속 중',
                    '$userCount명',
                    const Color(0xFF53CDC3),
                  ),
                  const SizedBox(width: 12),
                  _buildInfoCard(
                    Icons.article,
                    '게시글',
                    '$postCount개',
                    const Color(0xFFFF9800),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoCard(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF757680)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setMapStyle() async {
    if (_mapController != null) {
      final darkStyle = '''
[
  {
    "elementType": "geometry",
    "stylers": [{"color": "#242f3e"}]
  },
  {
    "elementType": "labels.text.stroke",
    "stylers": [{"color": "#242f3e"}]
  },
  {
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#746855"}]
  },
  {
    "featureType": "administrative.locality",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#d59563"}]
  },
  {
    "featureType": "poi",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#d59563"}]
  },
  {
    "featureType": "poi.park",
    "elementType": "geometry",
    "stylers": [{"color": "#263c3f"}]
  },
  {
    "featureType": "poi.park",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#6b9080"}]
  },
  {
    "featureType": "road",
    "elementType": "geometry",
    "stylers": [{"color": "#38414e"}]
  },
  {
    "featureType": "road",
    "elementType": "geometry.stroke",
    "stylers": [{"color": "#212a37"}]
  },
  {
    "featureType": "road",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#9ca5b0"}]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry",
    "stylers": [{"color": "#746855"}]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry.stroke",
    "stylers": [{"color": "#1f2835"}]
  },
  {
    "featureType": "road.highway",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#f3d19c"}]
  },
  {
    "featureType": "transit",
    "elementType": "geometry",
    "stylers": [{"color": "#2f3948"}]
  },
  {
    "featureType": "transit.station",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#d59563"}]
  },
  {
    "featureType": "water",
    "elementType": "geometry",
    "stylers": [{"color": "#17263c"}]
  },
  {
    "featureType": "water",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#515c6d"}]
  },
  {
    "featureType": "water",
    "elementType": "labels.text.stroke",
    "stylers": [{"color": "#17263c"}]
  }
]
      ''';
      await _mapController!.setMapStyle(darkStyle);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0C0E1F),
                Color(0xFF1D6477),
              ],
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // ─── [Layer 0] Google Map ───
              GoogleMap(
                initialCameraPosition: const CameraPosition(
                  target: _center,
                  zoom: 16.5,
                ),
                onMapCreated: (controller) {
                  _mapController = controller;
                  _setMapStyle();
                },
                circles: _buildCircles(),
                markers: const {}, // [수정] 지도 화면에서는 마커 제거 (원만 표시)
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                onTap: (latLng) {
                  // 검색 결과 닫기
                  if (_showSearchResults) {
                    setState(() => _showSearchResults = false);
                    _searchFocusNode.unfocus();
                    return;
                  }
                  // 가장 가까운 건물 찾기
                  Building? closest;
                  double minDist = double.infinity;
                  for (final b in CampusDataService.buildings) {
                    final dx = b.latitude - latLng.latitude;
                    final dy = b.longitude - latLng.longitude;
                    final dist = dx * dx + dy * dy;
                    if (dist < minDist) {
                      minDist = dist;
                      closest = b;
                    }
                  }
                  if (closest != null && minDist < 0.00001) {
                    _onBuildingTap(closest);
                  }
                },
              ),

              // ─── [Layer 1] 모드 토글 (검색 드롭다운보다 아래) ───
              Positioned(
                top: 76,
                left: 16,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildModeButton('users', '사용자', Icons.person),
                      _buildModeButton('posts', '게시글', Icons.article),
                    ],
                  ),
                ),
              ),

              // ─── [Layer 1] 데이터 로딩 표시 ───
              if (!_isDataLoaded)
                Positioned(
                  top: 120,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF53CDC3),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            '데이터 로딩 중...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // ─── [Layer 1] 현위치 FAB ───
              Positioned(
                bottom: 100,
                right: 16,
                child: FloatingActionButton.small(
                  heroTag: 'myLocation',
                  // [수정] _center(고정값) 대신 Geolocator.getCurrentPosition()으로 실제 GPS 위치 이동
                  onPressed: () async {
                    try {
                      // 위치 권한 확인
                      LocationPermission permission =
                          await Geolocator.checkPermission();
                      if (permission == LocationPermission.denied) {
                        permission = await Geolocator.requestPermission();
                      }
                      if (permission == LocationPermission.deniedForever ||
                          permission == LocationPermission.denied) {
                        return; // 권한 없으면 종료
                      }

                      // [수정] lastKnownPosition 금지 → getCurrentPosition 사용
                      final position = await Geolocator.getCurrentPosition(
                        desiredAccuracy: LocationAccuracy.high,
                      );

                      // [수정] CameraUpdate.newLatLng으로 정확한 좌표 이동
                      _mapController?.animateCamera(
                        CameraUpdate.newLatLng(
                          LatLng(position.latitude, position.longitude),
                        ),
                      );
                    } catch (_) {
                      // 위치 조회 실패 시 무시 (예: GPS 꺼짐)
                    }
                  },
                  backgroundColor: const Color(0xFF53CDC3),
                  child: const Icon(
                    Icons.my_location,
                    color: Colors.white,
                  ),
                ),
              ),

              // ─── [Layer 1] 새로고침 FAB ───
              Positioned(
                bottom: 50,
                right: 16,
                child: FloatingActionButton.small(
                  heroTag: 'refresh',
                  onPressed: _isRefreshing ? null : _refreshAll,
                  backgroundColor: Colors.white,
                  child: _isRefreshing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF53CDC3),
                          ),
                        )
                      : const Icon(
                          Icons.refresh,
                          color: Color(0xFF757680),
                        ),
                ),
              ),

              // ─── [Layer 2 최상단] 검색바 + 드롭다운 ───
              Positioned(
                top: 12,
                left: 16,
                right: 16,
                child: Material(
                  color: Colors.transparent,
                  elevation: 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 검색 입력
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 12,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          onChanged: (v) {
                            setState(() {
                              _searchQuery = v;
                              _showSearchResults = v.isNotEmpty;
                            });
                          },
                          onTap: () {
                            if (_searchController.text.isNotEmpty) {
                              setState(() => _showSearchResults = true);
                            }
                          },
                          decoration: InputDecoration(
                            hintText: '건물 검색...',
                            hintStyle:
                                const TextStyle(color: Color(0xFFB0B0B0)),
                            prefixIcon: const Icon(
                              Icons.search,
                              color: Color(0xFF757680),
                            ),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.close, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchQuery = '';
                                        _showSearchResults = false;
                                      });
                                      _searchFocusNode.unfocus();
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),

                      // 검색 결과 드롭다운 (최상단 z-index)
                      if (_showSearchResults &&
                          _filteredBuildings.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          constraints: const BoxConstraints(maxHeight: 280),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: ListView.separated(
                              shrinkWrap: true,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 4),
                              itemCount: _filteredBuildings.length,
                              separatorBuilder: (_, __) => const Divider(
                                height: 1,
                                indent: 16,
                                endIndent: 16,
                              ),
                              itemBuilder: (context, index) {
                                final building =
                                    _filteredBuildings[index];
                                final userCount =
                                    _userCounts[building.name] ?? 0;
                                final postCount =
                                    _postCounts[building.name] ?? 0;
                                return InkWell(
                                  onTap: () =>
                                      _moveCameraToBuilding(building),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.location_on,
                                          color: Color(0xFF53CDC3),
                                          size: 20,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            building.name,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFF141516),
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '${userCount}명 · ${postCount}개',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFFA5A5AC),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const OrbitBottomNavBar(currentIndex: 1),
    );
  }

  Widget _buildModeButton(String mode, String label, IconData icon) {
    final isActive = _mode == mode;
    return GestureDetector(
      onTap: () => setState(() => _mode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF53CDC3) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? Colors.white : const Color(0xFF757680),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isActive ? Colors.white : const Color(0xFF757680),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
