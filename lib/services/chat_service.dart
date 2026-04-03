import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/chat_room_model.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // [수정] 채팅방 목록 1회 조회 (Stream → Future)
  Future<List<ChatRoomModel>> getChatRooms() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];

    final snapshot = await _firestore
        .collection('chats')
        .where('users', arrayContains: uid)
        .get();

    final rooms = snapshot.docs
        .map((doc) => ChatRoomModel.fromFirestore(doc))
        .toList();
    // Dart에서 lastMessageAt 기준 내림차순 정렬
    rooms.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
    return rooms;
  }

  // [수정] 특정 채팅방 메시지 1회 조회 (Stream → Future)
  Future<List<MessageModel>> getMessages(String chatId) async {
    final snapshot = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .get();

    return snapshot.docs
        .map((doc) => MessageModel.fromFirestore(doc))
        .toList();
  }

  // 메시지 보내기
  Future<void> sendMessage(String chatId, String text) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final batch = _firestore.batch();

    // 메시지 추가
    final msgRef = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc();

    batch.set(msgRef, {
      'senderId': uid,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
      'read': false,
      'isSystem': false,
    });

    // 채팅방 최신 메시지 업데이트
    final chatRef = _firestore.collection('chats').doc(chatId);
    batch.update(chatRef, {
      'lastMessage': text,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageTime': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // 읽음 처리
  Future<void> markAsRead(String chatId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      await _firestore.collection('chats').doc(chatId).update({
        'lastRead_$uid': Timestamp.now(),
      });
    } catch (_) {}
  }

  // [수정] 읽지 않은 메시지 수 1회 조회 (Stream → Future)
  Future<int> getUnreadCount(String chatId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return 0;

    try {
      // 1. chatRoom 문서에서 lastRead 가져오기
      final chatDoc = await _firestore
          .collection('chats')
          .doc(chatId)
          .get();

      if (!chatDoc.exists) return 0;

      final lastRead = chatDoc.data()?['lastRead_$uid'] as Timestamp?;

      // 2. 메시지 목록 조회
      final messagesSnap = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('createdAt', descending: false)
          .get();

      // 3. unread 계산
      final count = messagesSnap.docs.where((d) {
        final data = d.data();
        if (data['senderId'] == uid) return false;
        if (data['isSystem'] == true) return false;
        final createdAt = data['createdAt'] as Timestamp?;
        if (createdAt == null) return false;
        if (lastRead == null) return true;
        return createdAt.compareTo(lastRead) > 0;
      }).length;

      return count;
    } catch (e) {
      debugPrint('[ChatService] getUnreadCount 오류: $e');
      return 0;
    }
  }

  // [수정] 상대방 lastRead 1회 조회 (Stream → Future)
  Future<Map<String, dynamic>> getOtherLastRead(String chatId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return {'otherUid': '', 'otherLastRead': null};

    try {
      final chatDoc = await _firestore
          .collection('chats')
          .doc(chatId)
          .get();

      if (!chatDoc.exists) return {'otherUid': '', 'otherLastRead': null};

      final data = chatDoc.data()!;
      final users = List<String>.from(data['users'] ?? []);
      final otherUid = users.firstWhere(
        (u) => u != uid,
        orElse: () => '',
      );

      final otherLastRead = data['lastRead_$otherUid'] as Timestamp?;

      return {
        'otherUid': otherUid,
        'otherLastRead': otherLastRead,
      };
    } catch (e) {
      debugPrint('[ChatService] getOtherLastRead 오류: $e');
      return {'otherUid': '', 'otherLastRead': null};
    }
  }

  // 채팅방 생성 (매칭 시)
  Future<String> createChatRoom({
    required String postId,
    required String requesterId,
    required String helperId,
    required Map<String, String> nicknames,
    required Map<String, String> schools,
  }) async {
    // 이미 존재하는 채팅방 확인
    try {
      final existing = await _firestore
          .collection('chats')
          .where('postId', isEqualTo: postId)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        return existing.docs.first.id;
      }
    } catch (_) {}

    final docRef = await _firestore.collection('chats').add({
      'postId': postId,
      'users': [requesterId, helperId],
      'requesterId': requesterId,
      'helperId': helperId,
      'nicknames': nicknames,
      'schools': schools,
      'lastMessage': '매칭이 완료되었습니다!',
      'lastMessageAt': FieldValue.serverTimestamp(),
    });

    // 시스템 메시지 추가
    await _firestore
        .collection('chats')
        .doc(docRef.id)
        .collection('messages')
        .add({
      'senderId': 'system',
      'text': '매칭이 완료되었습니다! 대화를 시작해보세요.',
      'createdAt': FieldValue.serverTimestamp(),
      'read': true,
      'isSystem': true,
    });

    return docRef.id;
  }

  // ─── [추가] 채팅 메시지 실시간 스트림 (읽음 처리 동기화용) ───
  Stream<List<MessageModel>> messagesStream(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MessageModel.fromFirestore(doc))
            .toList());
  }

  // ─── [추가] 상대방 lastRead 실시간 스트림 ───
  Stream<Timestamp?> otherLastReadStream(String chatId) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(null);

    return _firestore
        .collection('chats')
        .doc(chatId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      final data = doc.data()!;
      final users = List<String>.from(data['users'] ?? []);
      final otherUid = users.firstWhere(
        (u) => u != uid,
        orElse: () => '',
      );
      if (otherUid.isEmpty) return null;
      return data['lastRead_$otherUid'] as Timestamp?;
    });
  }

  // ─── [추가] 상대방이 보낸 읽지 않은 메시지를 read: true로 일괄 업데이트 ───
  Future<void> markMessagesAsRead(String chatId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      // read == false 인 메시지만 가져온 후 Dart에서 senderId 필터링
      // (Firestore 복합 인덱스 불필요)
      final snapshot = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('read', isEqualTo: false)
          .get();

      final unreadFromOther = snapshot.docs
          .where((doc) => doc.data()['senderId'] != uid)
          .toList();

      if (unreadFromOther.isEmpty) return;

      final batch = _firestore.batch();
      for (final doc in unreadFromOther) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('[ChatService] markMessagesAsRead 오류: $e');
    }
  }

  // postId로 채팅방 조회
  Future<String?> getChatRoomByPostId(String postId) async {
    try {
      final snapshot = await _firestore
          .collection('chats')
          .where('postId', isEqualTo: postId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      return snapshot.docs.first.id;
    } catch (e) {
      debugPrint('[ChatService] getChatRoomByPostId 오류: $e');
      return null;
    }
  }
}
