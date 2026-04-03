import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// [수정] PopScope(뒤로가기 2번 종료)를 위한 SystemNavigator import
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../services/post_service.dart';
import '../services/campus_data.dart';
import '../models/post_model.dart';
import '../widgets/bottom_nav_bar.dart';
import 'post_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PostService _postService = PostService();

  List<PostResDto> _posts = [];
  bool _isLoading = false; // [수정] 초기에는 false (데이터 없는 상태로 시작)
  int _sortIndex = 0; // 0: 모두 보기, 1: 거리순, 2: 높은 리워드, 3: 낮은 리워드
  DateTime? _lastBackPressed;
  double? _userLat;
  double? _userLng;
  bool _hasLoaded = false; // [추가] 1회라도 로드했는지 여부

  final List<String> _sortOptions = ['모두 보기', '거리순', '높은 리워드', '낮은 리워드'];

  @override
  void initState() {
    super.initState();
    _refreshAll(); // 최초 1회 자동 실행
  }

  /// [수정] 통합 새로고침: 위치 + 게시물 1회 로드
  Future<void> _refreshAll() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
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
          _userLat = position.latitude;
          _userLng = position.longitude;

          // 2️⃣ 내 위치 Firestore 저장 (1회)
          final userId = FirebaseAuth.instance.currentUser?.uid;
          if (userId != null) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .set({
              'lat': _userLat,
              'lng': _userLng,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          }
        }
      } catch (e) {
        debugPrint('[HOME] 위치 가져오기 실패: $e');
      }

      // 3️⃣ 게시물 목록 가져오기 (서버 API, 1회)
      final posts = await _postService.getAllPosts();
      debugPrint('[HOME] 서버에서 받은 게시물: ${posts.length}개');

      if (!mounted) return;

      // 4️⃣ 거리 계산 + 정렬
      final sortedPosts = _sortPosts(posts);

      setState(() {
        _posts = sortedPosts;
        _isLoading = false;
        _hasLoaded = true;
      });

      debugPrint('[HOME] 화면에 표시할 게시물: ${_posts.length}개');
    } catch (e) {
      debugPrint('[HOME] refreshAll 에러: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('새로고침 실패: $e')),
        );
      }
    }
  }

  List<PostResDto> _sortPosts(List<PostResDto> posts) {
    final List<PostResDto> sorted = List.from(posts);

    switch (_sortIndex) {
      case 0: // 모두 보기 (최신순)
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 1: // 거리순
        if (_userLat != null && _userLng != null) {
          sorted.sort((a, b) {
            final distA = CampusDataService.calculateDistance(
              _userLat!, _userLng!, a.latitude, a.longitude,
            );
            final distB = CampusDataService.calculateDistance(
              _userLat!, _userLng!, b.latitude, b.longitude,
            );
            return distA.compareTo(distB);
          });
        }
        break;
      case 2: // 높은 리워드
        sorted.sort((a, b) => b.point.compareTo(a.point));
        break;
      case 3: // 낮은 리워드
        sorted.sort((a, b) => a.point.compareTo(b.point));
        break;
    }

    return sorted;
  }

  String _getTimeAgo(int createdAt) {
    if (createdAt == 0) return '알 수 없음';
    try {
      final dateTime = DateTime.fromMillisecondsSinceEpoch(createdAt);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inSeconds < 60) {
        return '방금';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}분 전';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}시간 전';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}일 전';
      } else {
        return '${dateTime.month}월 ${dateTime.day}일';
      }
    } catch (e) {
      return '알 수 없음';
    }
  }

  String _getDistanceText(double distance) {
    if (distance < 1000) {
      return '${distance.toStringAsFixed(0)}m';
    } else {
      return '${(distance / 1000).toStringAsFixed(1)}km';
    }
  }

  String _formatPoint(int point) {
    if (point >= 1000) {
      final str = point.toString();
      final buffer = StringBuffer();
      for (int i = 0; i < str.length; i++) {
        if (i > 0 && (str.length - i) % 3 == 0) {
          buffer.write(',');
        }
        buffer.write(str[i]);
      }
      return buffer.toString();
    }
    return point.toString();
  }

  void _onSortChanged(int index) {
    setState(() {
      _sortIndex = index;
      _posts = _sortPosts(_posts);
    });
  }

  // [수정] PopScope onPopInvoked 핸들러 (WillPopScope 대신 사용)
  void _handlePopInvoked(bool didPop) {
    if (didPop) return;
    final now = DateTime.now();
    if (_lastBackPressed != null &&
        now.difference(_lastBackPressed!) < const Duration(seconds: 2)) {
      // 2초 내 두 번 누름 → 앱 종료
      SystemNavigator.pop();
      return;
    }
    _lastBackPressed = now;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('뒤로 버튼을 한 번 더 누르면 앱을 종료합니다.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // [수정] WillPopScope(deprecated) → PopScope 교체
    // canPop: false → 시스템이 자동으로 pop하지 않음
    // onPopInvoked에서 직접 종료 제어
    return PopScope(
      canPop: false,
      onPopInvoked: _handlePopInvoked,
      child: Scaffold(
        extendBodyBehindAppBar: false,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(0.0, -0.26),
              end: Alignment(0.0, 1.15),
              colors: [
                Color(0xFF0C0E1F),
                Color(0xFF1D6477),
              ],
            ),
          ),
          child: Column(
            children: [
              // ─── White Header Bar ───
              Container(
                width: screenWidth,
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    child: Row(
                      children: [
                        // 학교 이름 + 드롭다운
                        Row(
                          children: [
                            const Text(
                              '경희대학교',
                              style: TextStyle(
                                color: Color(0xFF141516),
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.keyboard_arrow_down,
                              color: const Color(0xFF141516),
                              size: 22,
                            ),
                          ],
                        ),
                        const Spacer(),
                        // 설정 아이콘
                        GestureDetector(
                          onTap: () {
                            Navigator.pushNamed(context, '/profile');
                          },
                          child: Icon(
                            Icons.settings_outlined,
                            color: const Color(0xFF141516),
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ─── Content Area ───
              Expanded(
                child: RefreshIndicator(
                  color: const Color(0xFF53CDC3),
                  onRefresh: _refreshAll,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ─── "요청 목록" Title Row ───
                          Row(
                            children: [
                              const Text(
                                '요청 목록',
                                style: TextStyle(
                                  color: Color(0xFFAAF5CF),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: _refreshAll,
                                child: Icon(
                                  Icons.refresh,
                                  color: const Color(0xFFAAF5CF),
                                  size: 18,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // ─── Sort Chips ───
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: List.generate(_sortOptions.length, (index) {
                                final isSelected = _sortIndex == index;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: GestureDetector(
                                    onTap: () => _onSortChanged(index),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 7,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? const Color(0xFFF4F4F4)
                                            : const Color(0xFF424A5E),
                                        borderRadius: BorderRadius.circular(19),
                                      ),
                                      child: Text(
                                        _sortOptions[index],
                                        style: TextStyle(
                                          color: isSelected
                                              ? const Color(0xFF141516)
                                              : const Color(0xFFA5A5AC),
                                          fontSize: 13,
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // ─── Post Cards ───
                          if (_isLoading)
                            const Padding(
                              padding: EdgeInsets.only(top: 60),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFF53CDC3),
                                ),
                              ),
                            )
                          else if (_posts.isEmpty)
                            const Padding(
                              padding: EdgeInsets.only(top: 60),
                              child: Center(
                                child: Text(
                                  '게시물이 없습니다',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            )
                          else ...[
                            ...List.generate(_posts.length, (index) {
                              final post = _posts[index];
                              return _buildPostCard(post);
                            }),
                            // ─── Footer ───
                            const SizedBox(height: 12),
                            Center(
                              child: Text(
                                '새로운 요청이 더 없어요.',
                                style: TextStyle(
                                  color: const Color(0xFFD5D6DA),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // ─── FAB ───
        // [수정] 글쓰기 FAB: 기존 원형 버튼+텍스트 전부 제거 → write.png 이미지만 사용
        floatingActionButton: GestureDetector(
          onTap: () async {
            final result = await Navigator.pushNamed(context, '/write_post');
            if (result == true) {
              _refreshAll();
            }
          },
          child: Image.asset(
            'assets/images/write.png',
            width: 56,
            height: 56,
            fit: BoxFit.contain,
          ),
        ),
        bottomNavigationBar: const OrbitBottomNavBar(currentIndex: 0),
      ),
    );
  }

  Widget _buildPostCard(PostResDto post) {
    // 거리 계산
    String? distanceText;
    if (_userLat != null && _userLng != null) {
      final dist = CampusDataService.calculateDistance(
        _userLat!, _userLng!, post.latitude, post.longitude,
      );
      distanceText = _getDistanceText(dist);
    }

    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PostDetailScreen(postId: post.postId),
          ),
        );
        // 상세에서 수락/완료 후 돌아오면 새로고침
        if (result == true) {
          _refreshAll();
        }
      },
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(23),
          border: Border.all(
            color: const Color(0xFFC8C8C8),
            width: 1.3,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: "요청" label + time ago
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '요청',
                  style: TextStyle(
                    color: Color(0xFF53CDC3),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  _getTimeAgo(post.createdAt),
                  style: const TextStyle(
                    color: Color(0xFFA5A5AC),
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Title
            Text(
              post.title,
              style: const TextStyle(
                color: Color(0xFF141516),
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),

            // Bottom Row: distance + point badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Distance
                if (distanceText != null)
                  Text(
                    distanceText,
                    style: const TextStyle(
                      color: Color(0xFFA5A5AC),
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                  )
                else
                  const SizedBox.shrink(),
                // Point badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF53CDC3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'P ${_formatPoint(post.point)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
