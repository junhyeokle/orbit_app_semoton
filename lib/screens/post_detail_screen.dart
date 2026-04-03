import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart'; // [추가] 사용자 위치 조회용
import '../services/post_service.dart';
import '../services/chat_service.dart';
import '../services/auth_service.dart';
import '../services/campus_data.dart';
import '../models/post_model.dart';
import '../widgets/ai_analysis_dialog.dart'; // [추가] AI 분석 팝업
import 'chat_screen.dart';

class PostDetailScreen extends StatefulWidget {
  final String postId;

  const PostDetailScreen({super.key, required this.postId});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final _postService = PostService();
  final _chatService = ChatService();
  final _authService = AuthService();

  PostResDto? _post;
  bool _isLoading = true;
  bool _isAccepting = false;
  bool _isCompleting = false;
  String? _errorMessage;

  // 작성자 정보
  String _authorNickname = '';
  String _authorSchool = '';

  // [수정] Firestore 상태 (1회 조회 기반)
  bool _firestoreCompleted = false;
  bool _firestoreAccepted = false;

  @override
  void initState() {
    super.initState();
    _loadPost();
    _loadFirestoreStatus(); // [수정] 1회 조회 (실시간 리스너 제거)
  }

  /// [수정] Firestore 문서의 accepted/completed 필드를 1회 조회 (snapshots 제거)
  Future<void> _loadFirestoreStatus() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .get();

      if (!mounted) return;
      if (doc.exists) {
        final data = doc.data();
        setState(() {
          _firestoreCompleted = data?['completed'] == true;
          _firestoreAccepted = data?['accepted'] == true;
        });
      }
    } catch (e) {
      debugPrint('[PostDetail] Firestore 상태 조회 실패: $e');
    }
  }

  Future<void> _loadPost() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      final post = await _postService.getPostDetail(widget.postId);
      if (mounted && post != null) {
        setState(() {
          _post = post;
          _isLoading = false;
        });
        _loadAuthorInfo(post.userId);
      } else if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '요청을 찾을 수 없습니다.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '요청을 불러올 수 없습니다.';
        });
      }
    }
  }

  Future<void> _loadAuthorInfo(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (doc.exists && mounted) {
        setState(() {
          _authorNickname =
              doc.data()?['nickName'] ?? doc.data()?['nickname'] ?? '알 수 없음';
          _authorSchool = doc.data()?['school'] ?? '';
        });
      }
    } catch (_) {}
  }

  /// 좌표에서 가장 가까운 건물 이름 찾기
  String _getBuildingNameFromCoordinates(double lat, double lng) {
    if (lat == 0 && lng == 0) return '위치 미설정';

    Building? closest;
    double minDist = double.infinity;

    for (final building in CampusDataService.buildings) {
      final dist = CampusDataService.calculateDistance(
        lat, lng, building.latitude, building.longitude,
      );
      if (dist < minDist) {
        minDist = dist;
        closest = building;
      }
    }

    if (closest != null && minDist < 500) {
      return closest.name;
    }
    return '알 수 없는 위치';
  }

  /// 수락 → API → 채팅방 생성 → 채팅 이동
  Future<void> _acceptPost() async {
    if (_post == null) return;
    setState(() => _isAccepting = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      // 1. API 수락 호출
      await _postService.acceptPost(widget.postId);

      // 2. 내 정보 가져오기
      final myProfile = await _authService.getFirestoreProfile();
      final myNickname = myProfile?['nickname'] ?? myProfile?['nickName'] ?? 'User';
      final mySchool = myProfile?['school'] ?? '';

      // 3. 채팅방 생성
      final chatId = await _chatService.createChatRoom(
        postId: widget.postId,
        requesterId: _post!.userId,
        helperId: uid,
        nicknames: {
          _post!.userId: _authorNickname,
          uid: myNickname,
        },
        schools: {
          _post!.userId: _authorSchool,
          uid: mySchool,
        },
      );

      // 4. 게시물 갱신
      final updatedPost = await _postService.getPostDetail(widget.postId);

      if (mounted) {
        setState(() {
          _post = updatedPost;
          _isAccepting = false;
        });

        // 5. 매칭 완료 알림
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              '매칭 완료',
              style: TextStyle(
                color: Color(0xFF141516),
                fontWeight: FontWeight.w700,
              ),
            ),
            content: const Text(
              '요청을 수락했습니다!\n채팅으로 이동하시겠습니까?',
              style: TextStyle(color: Color(0xFF4C4C4C)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  '나중에',
                  style: TextStyle(color: Color(0xFF757680)),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  // 채팅 화면 이동
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(
                        chatId: chatId,
                        otherNickname: _authorNickname,
                        otherSchool: _authorSchool,
                      ),
                    ),
                  );
                },
                child: const Text(
                  '채팅 이동',
                  style: TextStyle(
                    color: Color(0xFF53CDC3),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAccepting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('수락 실패: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  /// [수정] 완료 처리: Firestore 직접 업데이트 + 포인트 전달 + UI 실시간 반영
  Future<void> _completePost() async {
    if (_post == null) return;
    // [수정] Firestore 기준으로 이미 종료 여부 확인
    if (_firestoreCompleted || _post!.isCompleted) return;

    // [유지] "정말 완료하시겠습니까?" 확인 다이얼로그
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          '요청 완료',
          style: TextStyle(
            color: Color(0xFF141516),
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          '정말 완료하시겠습니까?\n수행자에게 ${_post!.point} 포인트가 전달됩니다.',
          style: const TextStyle(color: Color(0xFF4C4C4C)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              '취소',
              style: TextStyle(color: Color(0xFF757680)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              '완료',
              style: TextStyle(
                color: Color(0xFF53CDC3),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isCompleting = true);

    try {
      final firestore = FirebaseFirestore.instance;

      // [디버깅] 로그 출력
      print("postId: ${widget.postId}");

      // [수정] 1. Firestore 게시물 문서 직접 업데이트 — accepted + completed
      await firestore
          .collection('posts')
          .doc(widget.postId)
          .update({
        'accepted': true,
        'completed': true,
      });

      print("update 완료");

      // 2. 포인트 전달 (Firestore transaction)
      final acceptedUserId = _post!.acceptedUserId;

      if (acceptedUserId != null && acceptedUserId.isNotEmpty) {
        await firestore.runTransaction((transaction) async {
          final authorRef =
              firestore.collection('users').doc(_post!.userId);
          final helperRef =
              firestore.collection('users').doc(acceptedUserId);

          final authorSnap = await transaction.get(authorRef);
          final helperSnap = await transaction.get(helperRef);

          if (authorSnap.exists && helperSnap.exists) {
            final authorPoint = authorSnap.data()?['point'] ?? 0;
            final helperPoint = helperSnap.data()?['point'] ?? 0;

            final deductPoint =
                authorPoint >= _post!.point ? _post!.point : authorPoint;

            transaction.update(authorRef, {
              'point': authorPoint - deductPoint,
            });
            transaction.update(helperRef, {
              'point': helperPoint + deductPoint,
            });
          }
        });
      }

      if (mounted) {
        // 3. UI 즉시 반영 — _post를 completed 상태로 교체 + _firestoreCompleted
        setState(() {
          _isCompleting = false;
          _firestoreCompleted = true;
          _firestoreAccepted = true;
          _post = PostResDto(
            postId: _post!.postId,
            userId: _post!.userId,
            title: _post!.title,
            content: _post!.content,
            createdAt: _post!.createdAt,
            isAccept: true,
            acceptedUserId: _post!.acceptedUserId,
            latitude: _post!.latitude,
            longitude: _post!.longitude,
            rewardPoint: _post!.rewardPoint,
            isCompleted: true,
          );
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('요청이 완료되었습니다!'),
            backgroundColor: Color(0xFF53CDC3),
          ),
        );
      }
    } catch (e) {
      print("완료 처리 실패: $e");
      if (mounted) {
        setState(() => _isCompleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('완료 처리 실패: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  /// 기존 채팅방으로 이동
  Future<void> _navigateToChat() async {
    if (_post == null) return;

    try {
      final chatId = await _chatService.getChatRoomByPostId(widget.postId);
      if (chatId != null && mounted) {
        // 상대방 결정
        final uid = FirebaseAuth.instance.currentUser?.uid;
        final isOwner = uid == _post!.userId;
        String otherNickname = _authorNickname;
        String otherSchool = _authorSchool;

        if (isOwner && _post!.acceptedUserId != null) {
          // 작성자가 보는 경우 → 수행자 정보
          try {
            final helperDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(_post!.acceptedUserId!)
                .get();
            if (helperDoc.exists) {
              otherNickname = helperDoc.data()?['nickName'] ??
                  helperDoc.data()?['nickname'] ??
                  '수행자';
              otherSchool = helperDoc.data()?['school'] ?? '';
            }
          } catch (_) {}
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatId: chatId,
              otherNickname: otherNickname,
              otherSchool: otherSchool,
            ),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('채팅방을 찾을 수 없습니다'),
            backgroundColor: Color(0xFF757680),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('채팅 이동 실패: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // [수정] AI 분석 팝업: 연출 + 점수 계산 + 조언 생성 다이얼로그
  Future<void> _showAiAnalysis() async {
    if (_post == null) return;

    // 사용자 현재 위치 가져오기 (권한 있으면)
    double? userLat;
    double? userLng;
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        ).timeout(const Duration(seconds: 3), onTimeout: () {
          throw Exception('timeout');
        });
        userLat = pos.latitude;
        userLng = pos.longitude;
      }
    } catch (_) {
      // 위치 가져오기 실패해도 분석은 진행
    }

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false, // 분석 중 닫기 방지
      builder: (context) => AiAnalysisDialog(
        post: _post!,
        userLat: userLat,
        userLng: userLng,
      ),
    );
  }

  String _formatCreatedTime(int createdAt) {
    if (createdAt == 0) return '';
    try {
      final createdTime = DateTime.fromMillisecondsSinceEpoch(createdAt);
      final now = DateTime.now();
      final difference = now.difference(createdTime);

      if (difference.inMinutes < 60) {
        return '${difference.inMinutes}분 전';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}시간 전';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}일 전';
      } else {
        return '${createdTime.month}월 ${createdTime.day}일';
      }
    } catch (_) {
      return '';
    }
  }

  /// [수정] 실제 GoogleMap 위젯 렌더링 (인터랙션 비활성화, Marker 없음)
  Widget _buildMapPreview(double lat, double lng) {
    // 좌표가 없으면 placeholder 표시
    if (lat == 0 && lng == 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_off,
              color: Colors.white.withOpacity(0.4),
              size: 36,
            ),
            const SizedBox(height: 8),
            Text(
              '위치 미설정',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    final target = LatLng(lat, lng);

    // IgnorePointer로 드래그/확대/이동 등 모든 인터랙션 비활성화
    return IgnorePointer(
      child: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: target,
          zoom: 17.0,
        ),
        // [수정] 빨간 Marker 표시 (게시물 위치 표시용)
        markers: {
          Marker(
            markerId: const MarkerId('post_location'),
            position: target,
          ),
        },
        zoomGesturesEnabled: false,
        scrollGesturesEnabled: false,
        rotateGesturesEnabled: false,
        tiltGesturesEnabled: false,
        zoomControlsEnabled: false,
        myLocationEnabled: false,
        myLocationButtonEnabled: false,
        mapToolbarEnabled: false,
        liteModeEnabled: true,
      ),
    );
  }

  String _formatPoint(int point) {
    if (point >= 1000) {
      final str = point.toString();
      final buffer = StringBuffer();
      for (int i = 0; i < str.length; i++) {
        if (i > 0 && (str.length - i) % 3 == 0) buffer.write(',');
        buffer.write(str[i]);
      }
      return buffer.toString();
    }
    return point.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: Column(
        children: [
          // ─── 헤더 ───
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: const Color(0x1E000000),
                  blurRadius: 14,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 20, 16),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(
                          Icons.chevron_left,
                          color: Colors.black,
                          size: 28,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      '요청',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        height: 1.50,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ─── Content ───
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF53CDC3),
                    ),
                  )
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: Color(0xFF757680),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 16),
                            GestureDetector(
                              onTap: _loadPost,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF53CDC3),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  '다시 시도',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : _post == null
                        ? const Center(
                            child: Text(
                              '요청을 찾을 수 없습니다.',
                              style: TextStyle(
                                color: Color(0xFF757680),
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            color: const Color(0xFF53CDC3),
                            onRefresh: _loadPost,
                            child: SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              // [수정] 하단 시스템 네비게이션바 가림 방지 - MediaQuery bottom padding 적용
                              padding: EdgeInsets.only(
                                bottom: MediaQuery.of(context).padding.bottom,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // ─── 작성자 + 상태 + 시간 ───
                                  Container(
                                    width: double.infinity,
                                    color: Colors.white,
                                    padding: const EdgeInsets.fromLTRB(
                                        22, 16, 22, 16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // 작성자 정보
                                        Row(
                                          children: [
                                            // 프로필 아바타
                                            Container(
                                              width: 40,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF4F4F4),
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color:
                                                      const Color(0xFFBCBCBC),
                                                  width: 1,
                                                ),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  _authorNickname.isNotEmpty
                                                      ? _authorNickname[0]
                                                          .toUpperCase()
                                                      : '?',
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF757680),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    _authorNickname.isNotEmpty
                                                        ? _authorNickname
                                                        : '알 수 없음',
                                                    style: const TextStyle(
                                                      color: Color(0xFF141516),
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                  if (_authorSchool.isNotEmpty)
                                                    Text(
                                                      _authorSchool,
                                                      style: const TextStyle(
                                                        color:
                                                            Color(0xFFA5A5AC),
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            // [수정] 상태 배지: Firestore 실시간 기반 종료/진행 중/진행 전 3단계
                                            Builder(builder: (context) {
                                              // Firestore 상태 우선, fallback으로 _post 상태
                                              final completed = _firestoreCompleted || _post!.isCompleted;
                                              final accepted = _firestoreAccepted || _post!.isAccept;
                                              return Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: completed
                                                      ? const Color(0xFFEEEEEE) // 종료: 회색
                                                      : accepted
                                                          ? const Color(0xFFE8F5E9)
                                                          : const Color(0xFFFFF3E0),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  completed
                                                      ? '종료'
                                                      : accepted
                                                          ? '진행 중'
                                                          : '진행 전',
                                                  style: TextStyle(
                                                    color: completed
                                                        ? const Color(0xFF9E9E9E) // 종료: 회색
                                                        : accepted
                                                            ? const Color(0xFF2E7D32)
                                                            : const Color(
                                                                0xFFF57C00),
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              );
                                            }),
                                          ],
                                        ),

                                        const SizedBox(height: 16),

                                        // 제목
                                        Text(
                                          _post!.title,
                                          style: const TextStyle(
                                            color: Color(0xFF141516),
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            height: 1.4,
                                          ),
                                        ),

                                        const SizedBox(height: 8),

                                        // 시간
                                        Text(
                                          _formatCreatedTime(
                                              _post!.createdAt),
                                          style: const TextStyle(
                                            color: Color(0xFFA5A5AC),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 8),

                                  // ─── 요청 내용 ───
                                  Container(
                                    width: double.infinity,
                                    color: Colors.white,
                                    padding: const EdgeInsets.fromLTRB(
                                        22, 16, 22, 16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          '요청 내용',
                                          style: TextStyle(
                                            color: Color(0xFF141516),
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          _post!.content,
                                          style: const TextStyle(
                                            color: Color(0xFF4C4C4C),
                                            fontSize: 14,
                                            height: 1.6,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 8),

                                  // ─── 위치 (좌표 기반 건물 표시) ───
                                  Container(
                                    width: double.infinity,
                                    color: Colors.white,
                                    padding: const EdgeInsets.fromLTRB(
                                        22, 16, 22, 16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          '위치',
                                          style: TextStyle(
                                            color: Color(0xFF141516),
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 12),

                                        // 건물 위치 표시
                                        Row(
                                          children: [
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: const BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: Color(0xFF53CDC3),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              _getBuildingNameFromCoordinates(
                                                _post!.latitude,
                                                _post!.longitude,
                                              ),
                                              style: const TextStyle(
                                                color: Color(0xFF141516),
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),

                                        const SizedBox(height: 14),

                                        // [수정] 실제 GoogleMap 렌더링 (인터랙션 비활성화, Marker 없음)
                                        Container(
                                          width: double.infinity,
                                          height: 150,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF1A1C2E),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          clipBehavior: Clip.antiAlias,
                                          child: _buildMapPreview(
                                            _post!.latitude,
                                            _post!.longitude,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 8),

                                  // ─── 리워드 ───
                                  Container(
                                    width: double.infinity,
                                    color: Colors.white,
                                    padding: const EdgeInsets.fromLTRB(
                                        22, 16, 22, 16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          '리워드',
                                          style: TextStyle(
                                            color: Color(0xFF141516),
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 18,
                                            vertical: 14,
                                          ),
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [
                                                Color(0xFF53CDC3),
                                                Color(0xFF7DE5C6),
                                              ],
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(14),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const Icon(
                                                Icons.card_giftcard,
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 10),
                                              Text(
                                                '${_formatPoint(_post!.point)} P',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 16),

                                  // ─── AI 분석 버튼 ───
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 22),
                                    child: GestureDetector(
                                      onTap: _showAiAnalysis,
                                      child: Container(
                                        width: double.infinity,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: const Color(0xFF53CDC3),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: const Center(
                                          child: Text(
                                            'AI 분석 보기',
                                            style: TextStyle(
                                              color: Color(0xFF53CDC3),
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 12),

                                  // ─── 액션 버튼 ───
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 22),
                                    child: _buildActionButton(),
                                  ),

                                  const SizedBox(height: 30),
                                ],
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final isOwner = uid == _post!.userId;

    // [수정] Firestore 실시간 상태 우선 적용
    final bool completed = _firestoreCompleted || _post!.isCompleted;
    final bool accepted = _firestoreAccepted || _post!.isAccept;

    if (isOwner) {
      // 글쓴이
      if (accepted) {
        // [수정] 수락된 상태: 종료 여부에 따라 UI 분기
        final bool isCompleted = completed;
        final bool isDisabled = isCompleted || _isCompleting;

        return Column(
          children: [
            // [수정] 완료/종료 버튼
            GestureDetector(
              onTap: isDisabled ? null : _completePost,
              child: Container(
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  gradient: isDisabled
                      ? null
                      : const LinearGradient(
                          colors: [
                            Color(0xFF53CDC3),
                            Color(0xFF7DE5C6),
                          ],
                        ),
                  // [수정] 종료 시 회색 처리
                  color: isDisabled ? const Color(0xFFBCBCBC) : null,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: isDisabled
                      ? []
                      : [
                          BoxShadow(
                            color:
                                const Color(0xFF53CDC3).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: Center(
                  child: _isCompleting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          // [수정] 종료 시 텍스트 변경
                          isCompleted ? '종료' : '완료',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // 채팅 버튼
            GestureDetector(
              onTap: _navigateToChat,
              child: Container(
                width: double.infinity,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: const Color(0xFF53CDC3),
                    width: 1.5,
                  ),
                ),
                child: const Center(
                  child: Text(
                    '채팅하기',
                    style: TextStyle(
                      color: Color(0xFF53CDC3),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      } else {
        // 아직 수락 전 → 비활성 버튼
        return Container(
          width: double.infinity,
          height: 50,
          decoration: BoxDecoration(
            color: const Color(0xFFE0E0E0),
            borderRadius: BorderRadius.circular(25),
          ),
          child: const Center(
            child: Text(
              '수락 대기 중',
              style: TextStyle(
                color: Color(0xFFA5A5AC),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }
    } else {
      // 다른 사용자
      if (accepted) {
        // 이미 수락됨 → 비활성
        final isAcceptor = uid == _post!.acceptedUserId;
        if (isAcceptor) {
          // 수행자인 경우 → 채팅 버튼
          return GestureDetector(
            onTap: _navigateToChat,
            child: Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF53CDC3),
                    Color(0xFF7DE5C6),
                  ],
                ),
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF53CDC3).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  '채팅하기',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          );
        } else {
          // 다른 사람 → 비활성
          return Container(
            width: double.infinity,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFFE0E0E0),
              borderRadius: BorderRadius.circular(25),
            ),
            child: const Center(
              child: Text(
                '진행 중',
                style: TextStyle(
                  color: Color(0xFFA5A5AC),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }
      } else {
        // 수락 가능
        return GestureDetector(
          onTap: _isAccepting ? null : _acceptPost,
          child: Container(
            width: double.infinity,
            height: 50,
            decoration: BoxDecoration(
              gradient: _isAccepting
                  ? null
                  : const LinearGradient(
                      colors: [
                        Color(0xFF53CDC3),
                        Color(0xFF7DE5C6),
                      ],
                    ),
              color: _isAccepting ? const Color(0xFFBCBCBC) : null,
              borderRadius: BorderRadius.circular(25),
              boxShadow: _isAccepting
                  ? []
                  : [
                      BoxShadow(
                        color: const Color(0xFF53CDC3).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Center(
              child: _isAccepting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      '수락하기',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        );
      }
    }
  }
}
