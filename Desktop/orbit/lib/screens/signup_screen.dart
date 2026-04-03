import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _authService = AuthService();
  final _nicknameController = TextEditingController();
  final _idController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailLocalController = TextEditingController();

  bool _isLoading = false;
  bool _signupPressed = false;

  // 에러 메시지
  String? _nicknameError;
  String? _idError;
  String? _passwordError;
  String? _emailError;
  String? _schoolError;
  String? _majorError;

  // 이메일 도메인 선택
  String _selectedDomain = 'gmail.com';
  final _customDomainController = TextEditingController();
  bool _isCustomDomain = false;

  final List<String> _domainOptions = [
    'gmail.com',
    'naver.com',
    '기타',
  ];

  // 학교 선택
  String? _selectedSchool;
  final List<String> _schoolOptions = [
    '경희대학교',
    '서울대학교',
    '연세대학교',
    '고려대학교',
  ];

  // 학과 선택
  String? _selectedMajor;
  final List<String> _majorOptions = [
    '소프트웨어융합학과',
    '컴퓨터공학과',
    '인공지능학과',
    '시각디자인학과',
    '의류디자인학과',
  ];

  @override
  void dispose() {
    _nicknameController.dispose();
    _idController.dispose();
    _passwordController.dispose();
    _emailLocalController.dispose();
    _customDomainController.dispose();
    super.dispose();
  }

  String _getFullEmail() {
    final local = _emailLocalController.text.trim();
    final domain =
        _isCustomDomain ? _customDomainController.text.trim() : _selectedDomain;
    return '$local@$domain';
  }

  bool _validate() {
    bool valid = true;
    setState(() {
      _nicknameError = null;
      _idError = null;
      _passwordError = null;
      _emailError = null;
      _schoolError = null;
      _majorError = null;
    });

    // 닉네임: 10자 이하
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) {
      setState(() => _nicknameError = '닉네임을 입력해주세요');
      valid = false;
    } else if (nickname.length > 10) {
      setState(() => _nicknameError = '닉네임은 10자 이하로 입력해주세요');
      valid = false;
    }

    // 아이디: 영문 소문자만
    final id = _idController.text.trim();
    if (id.isEmpty) {
      setState(() => _idError = '아이디를 입력해주세요');
      valid = false;
    } else if (!RegExp(r'^[a-z]+$').hasMatch(id)) {
      setState(() => _idError = '영문 소문자만 사용해주세요');
      valid = false;
    }

    // 비밀번호: 8자 이상 영문+숫자
    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() => _passwordError = '비밀번호를 입력해주세요');
      valid = false;
    } else if (password.length < 8) {
      setState(() => _passwordError = '8자 이상 입력해주세요');
      valid = false;
    } else if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(password)) {
      setState(() => _passwordError = '영문과 숫자만 사용해주세요');
      valid = false;
    }

    // 이메일: 영문+숫자
    final emailLocal = _emailLocalController.text.trim();
    if (emailLocal.isEmpty) {
      setState(() => _emailError = '이메일을 입력해주세요');
      valid = false;
    } else if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(emailLocal)) {
      setState(() => _emailError = '영문과 숫자만 사용해주세요');
      valid = false;
    }

    // 기타 도메인인 경우 형식 검사
    if (_isCustomDomain) {
      final customDomain = _customDomainController.text.trim();
      if (customDomain.isEmpty ||
          !RegExp(r'^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(customDomain)) {
        setState(() => _emailError = '올바른 이메일 도메인을 입력해주세요');
        valid = false;
      }
    }

    // 학교
    if (_selectedSchool == null) {
      setState(() => _schoolError = '학교를 선택해주세요');
      valid = false;
    }

    // 학과
    if (_selectedMajor == null) {
      setState(() => _majorError = '학과를 선택해주세요');
      valid = false;
    }

    return valid;
  }

  Future<void> _signUp() async {
    if (!_validate()) return;

    setState(() => _isLoading = true);

    try {
      final email = _getFullEmail();
      await _authService.signUp(
        email: email,
        password: _passwordController.text,
        nickname: _nicknameController.text.trim(),
        id: _idController.text.trim(),
        school: _selectedSchool!,
        major: _selectedMajor!,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('회원가입 완료! 로그인해주세요.'),
            backgroundColor: Color(0xFF7DE5C6),
          ),
        );
        Navigator.pop(context); // 로그인 화면으로 복귀
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        if (e.code == 'email-already-in-use') {
          setState(() => _emailError = '이미 존재하는 값입니다');
        } else if (e.code == 'nickname-already-in-use') {
          setState(() => _nicknameError = '이미 존재하는 값입니다');
        } else if (e.code == 'id-already-in-use') {
          setState(() => _idError = '이미 존재하는 값입니다');
        } else if (e.code == 'weak-password') {
          setState(() => _passwordError = '더 강력한 비밀번호를 사용해주세요');
        } else if (e.code == 'invalid-email') {
          setState(() => _emailError = '올바른 이메일 형식이 아닙니다');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('회원가입 실패: ${e.message ?? e.code}'),
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

  void _showDomainPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D1D1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              ..._domainOptions.map((domain) {
                return ListTile(
                  title: Text(
                    domain,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF141516),
                    ),
                  ),
                  onTap: () {
                    setState(() {
                      if (domain == '기타') {
                        _isCustomDomain = true;
                        _selectedDomain = '';
                      } else {
                        _isCustomDomain = false;
                        _selectedDomain = domain;
                      }
                    });
                    Navigator.pop(context);
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showDropdownPicker({
    required String title,
    required List<String> options,
    required String? currentValue,
    required ValueChanged<String> onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D1D1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF141516),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ...options.map((option) {
                final isSelected = option == currentValue;
                return ListTile(
                  title: Text(
                    option,
                    style: TextStyle(
                      fontSize: 14,
                      color: isSelected
                          ? const Color(0xFF53CDC3)
                          : const Color(0xFF141516),
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: Color(0xFF53CDC3), size: 20)
                      : null,
                  onTap: () {
                    onSelected(option);
                    Navigator.pop(context);
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
                      '회원가입',
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

          // ─── 폼 영역 ───
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(35, 24, 35, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── 닉네임 ───
                  _buildFieldLabel('닉네임'),
                  const SizedBox(height: 4),
                  _buildTextField(
                    controller: _nicknameController,
                    hint: '10자 이하로 입력해주세요.',
                    error: _nicknameError,
                  ),
                  if (_nicknameError != null) _buildErrorText(_nicknameError!),
                  const SizedBox(height: 12),

                  // ─── 아이디 ───
                  _buildFieldLabel('아이디'),
                  const SizedBox(height: 4),
                  _buildTextField(
                    controller: _idController,
                    hint: '영문 소문자만 사용해주세요',
                    error: _idError,
                  ),
                  if (_idError != null) _buildErrorText(_idError!),
                  const SizedBox(height: 12),

                  // ─── 비밀번호 ───
                  _buildFieldLabel('비밀번호'),
                  const SizedBox(height: 4),
                  _buildTextField(
                    controller: _passwordController,
                    hint: '8자이상의 영문/ 숫자를 입력해주세요',
                    error: _passwordError,
                    obscureText: true,
                  ),
                  if (_passwordError != null)
                    _buildErrorText(_passwordError!),
                  const SizedBox(height: 12),

                  // ─── 이메일 ───
                  _buildFieldLabel('이메일'),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      // 이메일 로컬 파트
                      Expanded(
                        flex: 5,
                        child: _buildTextField(
                          controller: _emailLocalController,
                          hint: '이메일',
                          error: _emailError,
                          height: 40,
                        ),
                      ),
                      // @
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          '@',
                          style: TextStyle(
                            color: Color(0xFFA5A5AC),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      // 도메인 선택
                      Expanded(
                        flex: 4,
                        child: GestureDetector(
                          onTap: _showDomainPicker,
                          child: Container(
                            height: 40,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 15),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFD1D1D1),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _isCustomDomain
                                        ? (_customDomainController
                                                .text.isEmpty
                                            ? '직접입력'
                                            : _customDomainController.text)
                                        : _selectedDomain,
                                    style: TextStyle(
                                      color: (_isCustomDomain &&
                                              _customDomainController
                                                  .text.isEmpty)
                                          ? const Color(0xFF757680)
                                          : const Color(0xFF141516),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const Icon(
                                  Icons.keyboard_arrow_down,
                                  color: Color(0xFFA5A5AC),
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_emailError != null) _buildErrorText(_emailError!),
                  // 기타 도메인 직접 입력 필드
                  if (_isCustomDomain) ...[
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _customDomainController,
                      hint: '도메인을 입력하세요 (예: example.com)',
                      error: null,
                      height: 40,
                    ),
                  ],
                  const SizedBox(height: 12),

                  // ─── 학교 ───
                  _buildFieldLabel('학교'),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => _showDropdownPicker(
                      title: '학교 선택',
                      options: _schoolOptions,
                      currentValue: _selectedSchool,
                      onSelected: (value) {
                        setState(() {
                          _selectedSchool = value;
                          _schoolError = null;
                        });
                      },
                    ),
                    child: Container(
                      width: double.infinity,
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _schoolError != null
                              ? Colors.red
                              : const Color(0xFFD1D1D1),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _selectedSchool ?? '학교 찾기',
                              style: TextStyle(
                                color: _selectedSchool != null
                                    ? const Color(0xFF141516)
                                    : const Color(0xFF757680),
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                height: 1.50,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.keyboard_arrow_down,
                            color: Color(0xFFA5A5AC),
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_schoolError != null) _buildErrorText(_schoolError!),
                  const SizedBox(height: 12),

                  // ─── 학과 ───
                  _buildFieldLabel('학과'),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => _showDropdownPicker(
                      title: '학과 선택',
                      options: _majorOptions,
                      currentValue: _selectedMajor,
                      onSelected: (value) {
                        setState(() {
                          _selectedMajor = value;
                          _majorError = null;
                        });
                      },
                    ),
                    child: Container(
                      width: double.infinity,
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _majorError != null
                              ? Colors.red
                              : const Color(0xFFD1D1D1),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _selectedMajor ?? '학과 찾기',
                              style: TextStyle(
                                color: _selectedMajor != null
                                    ? const Color(0xFF141516)
                                    : const Color(0xFF757680),
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                height: 1.50,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.keyboard_arrow_down,
                            color: Color(0xFFA5A5AC),
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_majorError != null) _buildErrorText(_majorError!),
                  const SizedBox(height: 40),

                  // ─── 회원가입 버튼 ───
                  GestureDetector(
                    onTapDown: (_) => setState(() => _signupPressed = true),
                    onTapUp: (_) {
                      setState(() => _signupPressed = false);
                      if (!_isLoading) _signUp();
                    },
                    onTapCancel: () =>
                        setState(() => _signupPressed = false),
                    child: AnimatedScale(
                      scale: _signupPressed ? 0.96 : 1.0,
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
                                  '회원가입',
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
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xFF4C4C4C),
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.50,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    String? error,
    bool obscureText = false,
    double height = 40,
  }) {
    return SizedBox(
      height: height,
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        style: const TextStyle(
          color: Color(0xFF141516),
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            color: Color(0xFF757680),
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),
          filled: true,
          fillColor: const Color(0xFFF5F5F5),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 10,
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
              color:
                  error != null ? Colors.red : const Color(0xFFD1D1D1),
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color:
                  error != null ? Colors.red : const Color(0xFF53CDC3),
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorText(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.red,
          fontSize: 10,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}
