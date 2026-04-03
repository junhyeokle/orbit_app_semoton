import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authService = AuthService();
  final _idController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _idError;
  String? _passwordError;

  bool _loginPressed = false;
  bool _googlePressed = false;

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _idError = null;
      _passwordError = null;
    });

    final id = _idController.text.trim();
    final password = _passwordController.text;

    if (id.isEmpty) {
      setState(() => _idError = '아이디를 입력해주세요');
      return;
    }
    if (password.isEmpty) {
      setState(() => _passwordError = '비밀번호를 입력해주세요');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Firestore에서 아이디로 이메일 조회 후 Firebase Auth 로그인
      await _authService.signInWithId(id, password);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('로그인 성공!'),
            backgroundColor: Color(0xFF7DE5C6),
          ),
        );
        Navigator.pushReplacementNamed(context, '/home');
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        if (e.code == 'user-not-found' || e.code == 'invalid-email') {
          setState(() => _idError = '해당 아이디가 존재하지 않습니다');
        } else if (e.code == 'wrong-password' ||
            e.code == 'invalid-credential') {
          setState(() => _passwordError = '비밀번호가 일치하지 않습니다');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('로그인 실패: ${e.message ?? e.code}'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류 발생: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _googleLogin() async {
    setState(() => _isLoading = true);
    try {
      await _authService.signInWithGoogle();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Google 로그인 성공!'),
            backgroundColor: Color(0xFF7DE5C6),
          ),
        );
        Navigator.pushReplacementNamed(context, '/home');
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String msg = 'Google 로그인 실패';
        if (e.code == 'google-sign-in-cancelled') {
          msg = 'Google 로그인이 취소되었습니다.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google 로그인 실패: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 34),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── 상단 여백 (비율) ───
              const Spacer(flex: 3),

              // ─── [수정] ORBIT 로고: star_light.png 이미지 사용 (라이트 버전) ───
              Image.asset(
                'assets/images/star_light.png',
                width: 48,
                height: 48,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const SizedBox(
                  width: 48,
                  height: 48,
                  child: Icon(
                    Icons.auto_awesome,
                    color: Color(0xFF53CDC3),
                    size: 36,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'ORBIT',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 36,
                  fontFamily: 'PretendardBlack', // [수정] PretendardBlack 폰트 적용
                  fontWeight: FontWeight.bold,
                  height: 1.50,
                  letterSpacing: 7.20,
                ),
              ),

              const Spacer(flex: 3),

              // ─── CAMPUS ID 필드 ───
              const Text(
                'CAMPUS ID',
                style: TextStyle(
                  color: Color(0xFF4C4C4C),
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  height: 1.50,
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 52,
                child: TextField(
                  controller: _idController,
                  style: const TextStyle(
                    color: Color(0xFF141516),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: '아이디를 입력하세요.',
                    hintStyle: const TextStyle(
                      color: Color(0xFF707070),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 16,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFFD1D1D1),
                        width: 1,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: _idError != null
                            ? Colors.red
                            : const Color(0xFFD1D1D1),
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: _idError != null
                            ? Colors.red
                            : const Color(0xFF53CDC3),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              if (_idError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4),
                  child: Text(
                    _idError!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 11,
                    ),
                  ),
                ),
              const SizedBox(height: 10),

              // ─── PASSWORD 필드 ───
              const Text(
                'PASSWORD',
                style: TextStyle(
                  color: Color(0xFF4C4C4C),
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  height: 1.50,
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 52,
                child: TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: const TextStyle(
                    color: Color(0xFF141516),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: '비밀번호를 입력하세요.',
                    hintStyle: const TextStyle(
                      color: Color(0xFF707070),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 16,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: const Color(0xFFA5A5AC),
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFFD1D1D1),
                        width: 1,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: _passwordError != null
                            ? Colors.red
                            : const Color(0xFFD1D1D1),
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: _passwordError != null
                            ? Colors.red
                            : const Color(0xFF53CDC3),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              if (_passwordError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4),
                  child: Text(
                    _passwordError!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 11,
                    ),
                  ),
                ),
              const SizedBox(height: 20),

              // ─── 로그인 버튼 ───
              GestureDetector(
                onTapDown: (_) => setState(() => _loginPressed = true),
                onTapUp: (_) {
                  setState(() => _loginPressed = false);
                  if (!_isLoading) _login();
                },
                onTapCancel: () => setState(() => _loginPressed = false),
                child: AnimatedScale(
                  scale: _loginPressed ? 0.96 : 1.0,
                  duration: const Duration(milliseconds: 100),
                  child: Container(
                    width: double.infinity,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF7DE5C6),
                      borderRadius: BorderRadius.circular(59),
                    ),
                    child: Center(
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              '로그인',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                height: 1.50,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // ─── 아이디 찾기 | 비밀번호 찾기 | 회원가입 ───
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () {},
                    child: const Text(
                      '아이디 찾기',
                      style: TextStyle(
                        color: Color(0xFFA5A5AC),
                        fontSize: 11,
                        fontWeight: FontWeight.w300,
                        height: 1.50,
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Container(width: 1, height: 10, color: const Color(0xFFD1D1D1)),
                  const SizedBox(width: 18),
                  GestureDetector(
                    onTap: () {},
                    child: const Text(
                      '비밀번호 찾기',
                      style: TextStyle(
                        color: Color(0xFFA5A5AC),
                        fontSize: 11,
                        fontWeight: FontWeight.w300,
                        height: 1.50,
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Container(width: 1, height: 10, color: const Color(0xFFD1D1D1)),
                  const SizedBox(width: 18),
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/signup'),
                    child: const Text(
                      '회원가입',
                      style: TextStyle(
                        color: Color(0xFFA5A5AC),
                        fontSize: 11,
                        fontWeight: FontWeight.w300,
                        height: 1.50,
                      ),
                    ),
                  ),
                ],
              ),

              const Spacer(flex: 5),

              // ─── SNS 간편연동 ───
              Row(
                children: [
                  Expanded(
                    child: Container(height: 1, color: const Color(0xFFE0E0E0)),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'SNS 간편연동',
                      style: TextStyle(
                        color: Color(0xFFA5A5AC),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(height: 1, color: const Color(0xFFE0E0E0)),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ─── SNS 원형 버튼 ───
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildSnsCircle(onTap: () {}),
                  const SizedBox(width: 32),
                  GestureDetector(
                    onTapDown: (_) => setState(() => _googlePressed = true),
                    onTapUp: (_) {
                      setState(() => _googlePressed = false);
                      if (!_isLoading) _googleLogin();
                    },
                    onTapCancel: () => setState(() => _googlePressed = false),
                    child: AnimatedScale(
                      scale: _googlePressed ? 0.9 : 1.0,
                      duration: const Duration(milliseconds: 100),
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: const BoxDecoration(
                          color: Color(0xFFD9D9D9),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Text(
                            'G',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF757680),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 32),
                  _buildSnsCircle(onTap: () {}),
                ],
              ),

              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSnsCircle({required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: const BoxDecoration(
          color: Color(0xFFD9D9D9),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
