import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/chat_service.dart';
import '../models/chat_room_model.dart';
import 'post_detail_screen.dart';

class ChatScreen extends StatefulWidget {
  final String? chatId;
  final String? otherNickname;
  final String? otherSchool;
  final String? postId;

  const ChatScreen({
    super.key,
    this.chatId,
    this.otherNickname,
    this.otherSchool,
    this.postId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _chatService = ChatService();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  // [수정] Stream 기반 실시간 구독으로 변경
  StreamSubscription<Timestamp?>? _lastReadSub;
  Timestamp? _otherLastRead;

  @override
  void initState() {
    super.initState();
    if (widget.chatId != null) {
      // 입장 시 읽음 처리 (lastRead 타임스탬프 + 개별 메시지 read 필드)
      _chatService.markAsRead(widget.chatId!);
      _chatService.markMessagesAsRead(widget.chatId!);

      // 상대방 lastRead 실시간 구독 (sender가 '1' 표시 제거용)
      _lastReadSub = _chatService
          .otherLastReadStream(widget.chatId!)
          .listen((ts) {
        if (mounted) {
          setState(() => _otherLastRead = ts);
        }
      });
    }
  }

  @override
  void dispose() {
    _lastReadSub?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty || widget.chatId == null) return;

    _chatService.sendMessage(widget.chatId!, text);
    _messageController.clear();
    _chatService.markAsRead(widget.chatId!);
  }

  /// 새 메시지 수신 시 자동 스크롤
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(
          _scrollController.position.maxScrollExtent,
        );
      }
    });
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = hour < 12 ? '오전' : '오후';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$period $displayHour:$minute';
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return '오늘';
    }
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    return '${dt.year}년 ${dt.month}월 ${dt.day}일 ${weekdays[dt.weekday - 1]}요일';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.chatId == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0C0E1F),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('채팅'),
        ),
        body: const Center(child: Text('채팅방을 선택해주세요.')),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.otherNickname ?? '',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            if (widget.otherSchool != null && widget.otherSchool!.isNotEmpty)
              Text(
                widget.otherSchool!,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.6),
                  fontWeight: FontWeight.w400,
                ),
              ),
          ],
        ),
        centerTitle: true,
        actions: [
          if (widget.postId != null && widget.postId!.isNotEmpty)
            IconButton(
              icon: const Icon(
                Icons.article_outlined,
                color: Colors.white,
                size: 22,
              ),
              tooltip: '게시물 보기',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        PostDetailScreen(postId: widget.postId!),
                  ),
                );
              },
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
        child: Column(
          children: [
            // [수정] StreamBuilder 기반 실시간 메시지 목록
            Expanded(
              child: StreamBuilder<List<MessageModel>>(
                stream: _chatService.messagesStream(widget.chatId!),
                builder: (context, snapshot) {
                  // 새 메시지가 올 때마다 읽음 처리
                  if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                    // 상대방이 보낸 읽지 않은 메시지가 있으면 읽음 처리
                    final hasUnread = snapshot.data!.any(
                      (m) => m.senderId != _uid && !m.read && !m.isSystem,
                    );
                    if (hasUnread) {
                      // 비동기로 처리 (build 중 setState 방지)
                      Future.microtask(() {
                        _chatService.markAsRead(widget.chatId!);
                        _chatService.markMessagesAsRead(widget.chatId!);
                      });
                    }
                    _scrollToBottom();
                  }

                  if (!snapshot.hasData) {
                    return SafeArea(
                      child: Center(
                        child: CircularProgressIndicator(
                          color: const Color(0xFF53CDC3),
                        ),
                      ),
                    );
                  }

                  final messages = snapshot.data!;
                  if (messages.isEmpty) {
                    return SafeArea(
                      child: Center(
                        child: Text(
                          '대화를 시작해보세요!',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                          ),
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(
                      top: 80,
                      left: 16,
                      right: 16,
                      bottom: 12,
                    ),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final showDate = index == 0 ||
                          _formatDate(messages[index - 1].createdAt) !=
                              _formatDate(msg.createdAt);

                      return Column(
                        children: [
                          if (showDate) _buildDateSeparator(msg.createdAt),
                          if (msg.isSystem)
                            _buildSystemMessage(msg)
                          else
                            _buildMessageBubble(msg),
                        ],
                      );
                    },
                  );
                },
              ),
            ),

            // 입력 필드
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                color: Colors.transparent,
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1C2E).withOpacity(0.8),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        child: TextField(
                          controller: _messageController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: '메시지 입력...',
                            hintStyle: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                            ),
                            border: InputBorder.none,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 10),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _sendMessage,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: Color(0xFF53CDC3),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.send,
                          size: 18,
                          color: Colors.white,
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
    );
  }

  Widget _buildDateSeparator(DateTime dt) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _formatDate(dt),
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSystemMessage(MessageModel msg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1976D2).withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF1976D2).withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Text(
            msg.text,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF64B5F6),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(MessageModel msg) {
    final isMine = msg.senderId == _uid;

    // [수정] read 필드 기반 읽음 표시: 내 메시지이고 상대방이 아직 안 읽은 경우 '1' 표시
    final showUnread = isMine && !msg.read;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) ...[
            // 상대방 메시지
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(4),
                    bottomRight: Radius.circular(16),
                  ),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Text(
                  msg.text,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              _formatTime(msg.createdAt),
              style: TextStyle(
                fontSize: 10,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
          ] else ...[
            // 내 메시지
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(msg.createdAt),
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
                // [수정] read == false 일 때만 '1' 표시 → 상대방이 읽으면 실시간으로 사라짐
                if (showUnread)
                  const Text(
                    '1',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF75CAC2),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFF53CDC3),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(4),
                  ),
                ),
                child: Text(
                  msg.text,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
