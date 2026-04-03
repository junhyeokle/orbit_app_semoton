import 'package:cloud_firestore/cloud_firestore.dart';

class ChatRoomModel {
  final String id;
  final String postId;
  final List<String> users;
  final String requesterId;
  final String helperId;
  final Map<String, String> nicknames;
  final Map<String, String> schools;
  final String lastMessage;
  final DateTime lastMessageAt;
  // [수정] 메시지 전송 시 업데이트되는 실제 마지막 메시지 시간
  final DateTime? lastMessageTime;

  ChatRoomModel({
    required this.id,
    required this.postId,
    required this.users,
    required this.requesterId,
    required this.helperId,
    required this.nicknames,
    required this.schools,
    required this.lastMessage,
    required this.lastMessageAt,
    this.lastMessageTime,
  });

  factory ChatRoomModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatRoomModel(
      id: doc.id,
      postId: data['postId'] ?? '',
      users: List<String>.from(data['users'] ?? []),
      requesterId: data['requesterId'] ?? '',
      helperId: data['helperId'] ?? '',
      nicknames: Map<String, String>.from(data['nicknames'] ?? {}),
      schools: Map<String, String>.from(data['schools'] ?? {}),
      lastMessage: data['lastMessage'] ?? '',
      lastMessageAt: (data['lastMessageAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      // [수정] lastMessageTime 필드 읽기 (없으면 lastMessageAt 사용)
      lastMessageTime: (data['lastMessageTime'] as Timestamp?)?.toDate(),
    );
  }

  /// [수정] 표시용 시간: lastMessageTime 우선, 없으면 lastMessageAt
  DateTime get displayTime => lastMessageTime ?? lastMessageAt;
}

class MessageModel {
  final String id;
  final String senderId;
  final String text;
  final DateTime createdAt;
  final bool read;
  final bool isSystem;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.text,
    required this.createdAt,
    required this.read,
    this.isSystem = false,
  });

  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MessageModel(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      text: data['text'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      read: data['read'] ?? false,
      isSystem: data['isSystem'] ?? false,
    );
  }
}
