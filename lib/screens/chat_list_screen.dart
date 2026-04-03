import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/chat_service.dart';
import '../models/chat_room_model.dart';
import '../widgets/bottom_nav_bar.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _chatService = ChatService();
  final _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  // [수정] 수동 로드 기반 상태 변수
  List<ChatRoomModel> _rooms = [];
  Map<String, int> _unreadCounts = {}; // 채팅방별 unread count 캐시
  bool _isLoading = false;
  bool _hasLoaded = false;

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${dt.month}/${dt.day}';
  }

  @override
  void initState() {
    super.initState();
    _refreshAll(); // 최초 1회 자동 실행
  }

  /// [수정] 채팅방 목록 + unread count 1회 조회
  Future<void> _refreshAll() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // 1️⃣ 채팅방 목록 가져오기 (Firestore 1회)
      final rooms = await _chatService.getChatRooms();

      // 2️⃣ 각 채팅방별 unread count 가져오기 (1회)
      final Map<String, int> counts = {};
      for (final room in rooms) {
        counts[room.id] = await _chatService.getUnreadCount(room.id);
      }

      if (mounted) {
        setState(() {
          _rooms = rooms;
          _unreadCounts = counts;
          _isLoading = false;
          _hasLoaded = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          '채팅',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        centerTitle: false,
        // [추가] 새로고침 버튼
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _isLoading ? null : _refreshAll,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0C0E1F),
              Color(0xFF1D6477),
            ],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF53CDC3),
                  ),
                )
              : _rooms.isEmpty && !_hasLoaded
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF53CDC3),
                      ),
                    )
                  : _rooms.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 64,
                                color: Colors.white.withOpacity(0.4),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                '아직 채팅이 없어요.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white.withOpacity(0.7),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '요청을 수락하면 채팅이 시작돼요!',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withOpacity(0.5),
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          color: const Color(0xFF53CDC3),
                          onRefresh: _refreshAll,
                          child: ListView.builder(
                            itemCount: _rooms.length,
                            padding: const EdgeInsets.only(top: 8, bottom: 16),
                            itemBuilder: (context, index) {
                              return _buildChatRoomItem(_rooms[index]);
                            },
                          ),
                        ),
        ),
      ),
      bottomNavigationBar: const OrbitBottomNavBar(currentIndex: 2),
    );
  }

  Widget _buildChatRoomItem(ChatRoomModel room) {
    // 상대방 uid
    final otherUid = room.users.firstWhere(
      (uid) => uid != _uid,
      orElse: () => '',
    );
    final otherNickname = room.nicknames[otherUid] ?? '알 수 없음';
    final otherSchool = room.schools[otherUid] ?? '';
    final unreadCount = _unreadCounts[room.id] ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: GestureDetector(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                chatId: room.id,
                otherNickname: otherNickname,
                otherSchool: otherSchool,
                postId: room.postId,
              ),
            ),
          );
          // 채팅에서 돌아오면 새로고침
          _refreshAll();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // 아바타
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFF53CDC3),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    otherNickname.isNotEmpty ? otherNickname[0] : '?',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // 정보 (왼쪽 영역)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      otherNickname,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      room.lastMessage,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // [수정] 오른쪽: 시간 + unread count (1회 조회 기반)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _timeAgo(room.displayTime),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                  if (unreadCount > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
