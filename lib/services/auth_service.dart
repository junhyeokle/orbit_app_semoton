import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'api_service.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final ApiService _apiService = ApiService();

  User? get currentUser => _auth.currentUser;

  /// Firebase ID Token 가져오기
  Future<String?> getIdToken() async {
    return await _auth.currentUser?.getIdToken();
  }

  /// 아이디 기반 로그인: Firestore에서 id로 email 조회 후 Firebase Auth 로그인
  Future<UserCredential> signInWithId(String id, String password) async {
    // 1. Firestore에서 id로 사용자 조회
    final querySnapshot = await _firestore
        .collection('users')
        .where('id', isEqualTo: id)
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: '해당 아이디가 존재하지 않습니다',
      );
    }

    // 2. 해당 email 가져오기
    final userData = querySnapshot.docs.first.data();
    final email = userData['email'] as String;

    // 3. Firebase Auth 로그인
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    // 서버에 로그인 알림
    await _apiService.login();
    return credential;
  }

  /// 이메일/비밀번호 로그인 후 서버에 토큰 전달 (기존 호환용)
  Future<UserCredential> signInWithEmail(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    await _apiService.login();
    return credential;
  }

  /// 회원가입: Firebase Auth + Firestore 저장 (서버 호출 없음)
  Future<UserCredential> signUp({
    required String email,
    required String password,
    required String nickname,
    required String id,
    required String school,
    required String major,
  }) async {
    // 중복 검사: 닉네임
    final nicknameCheck = await _firestore
        .collection('users')
        .where('nickname', isEqualTo: nickname)
        .limit(1)
        .get();
    if (nicknameCheck.docs.isNotEmpty) {
      throw FirebaseAuthException(
        code: 'nickname-already-in-use',
        message: '이미 존재하는 닉네임입니다',
      );
    }

    // 중복 검사: 아이디
    final idCheck = await _firestore
        .collection('users')
        .where('id', isEqualTo: id)
        .limit(1)
        .get();
    if (idCheck.docs.isNotEmpty) {
      throw FirebaseAuthException(
        code: 'id-already-in-use',
        message: '이미 존재하는 아이디입니다',
      );
    }

    // Firebase Auth 계정 생성
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // displayName에 닉네임 저장
    await credential.user?.updateDisplayName(nickname);

    // Firestore users 컬렉션에 저장
    final uid = credential.user!.uid;
    // [수정] doc 존재 여부 체크: 신규 회원에게만 포인트 3000 지급
    final existingDoc = await _firestore.collection('users').doc(uid).get();
    if (!existingDoc.exists) {
      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'id': id,
        'nickname': nickname,
        'email': email,
        'school': school,
        'department': major,
        'point': 3000, // [수정] 신규 가입 시 3000 포인트 지급
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    return credential;
  }

  /// Google 로그인
  Future<UserCredential> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw FirebaseAuthException(
        code: 'google-sign-in-cancelled',
        message: 'Google 로그인이 취소되었습니다.',
      );
    }

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);

    // Firestore에 유저 정보가 없으면 기본값으로 생성
    final uid = userCredential.user!.uid;
    final doc = await _firestore.collection('users').doc(uid).get();
    // [수정] 기존 유저 중복 지급 금지: doc 없을 때만 3000 포인트 지급
    if (!doc.exists) {
      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'id': userCredential.user?.email?.split('@').first ?? '',
        'nickname': userCredential.user?.displayName ?? 'User',
        'email': userCredential.user?.email ?? '',
        'school': '',
        'department': '',
        'point': 3000, // [수정] 신규 Google 로그인 유저에게 3000 포인트 지급
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    // 서버에 로그인(등록)
    await _apiService.login();
    return userCredential;
  }

  /// 로그아웃
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  /// Firestore에서 현재 사용자 프로필 가져오기
  Future<Map<String, dynamic>?> getFirestoreProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (doc.exists) {
      return doc.data();
    }
    return null;
  }

  /// Firestore 프로필 업데이트
  Future<void> updateFirestoreProfile(Map<String, dynamic> data) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _firestore.collection('users').doc(user.uid).update(data);
  }

  /// 본인 정보 조회 (REST API)
  Future<UserResDto?> getMyProfile() async {
    return await _apiService.getMyProfile();
  }

  /// 유저 조회 (REST API)
  Future<UserResDto?> getUserById(String userId) async {
    return await _apiService.getUserById(userId);
  }
}
