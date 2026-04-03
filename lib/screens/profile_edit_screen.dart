import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _authService = AuthService();
  final _nicknameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _savePressed = false;

  String? _selectedSchool;
  String? _selectedMajor;

  String? _nicknameError;
  String? _emailError;
  String? _passwordError;

  final List<String> _schoolOptions = [
    '경희대학교',
    '서울대학교',
    '연세대학교',
    '고려대학교',
  ];

  final List<String> _majorOptions = [
    '소프트웨어융합학과',
    '컴퓨터공학과',
    '인공지능학과',
    '시각디자인학과',
    '의류디자인학과',
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentProfile();
  }

  Future<void> _loadCurrentProfile() async {
    try {
      final profile = await _authService.getFirestoreProfile();
      if (mounted && profile != null) {
        setState(() {
          _nicknameController.text = profile['nickname'] ?? '';
          _emailController.text = profile['email'] ?? '';
          _selectedSchool = profile['school'];
          _selectedMajor = profile['department'];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    setState(() {
      _nicknameError = null;
      _emailError = null;
      _passwordError = null;
    });

    bool valid = true;
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) {
      setState(() => _nicknameError = '닉네임을 입력해주세요');
      valid = false;
    } else if (nickname.length > 10) {
      setState(() => _nicknameError = '닉네임은 10자 이하로 입력해주세요');
      valid = false;
    }

    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _emailError = '이메일을 입력해주세요');
      valid = false;
    } else if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email)) {
      setState(() => _emailError = '올바른 이메일 형식이 아닙니다');
      valid = false;
    }

    final password = _passwordController.text;
    if (password.isNotEmpty && password.length < 8) {
      setState(() => _passwordError = '8자 이상 입력해주세요');
      valid = false;
    }

    if (!valid) return;

    setState(() => _isSaving = true);

    try {
      // Firestore 업데이트
      final updates = <String, dynamic>{
        'nickname': nickname,
        'email': email,
      };
      if (_selectedSchool != null) updates['school'] = _selectedSchool;
      if (_selectedMajor != null) updates['department'] = _selectedMajor;

      await _authService.updateFirestoreProfile(updates);

      // Firebase Auth displayName 업데이트
      await FirebaseAuth.instance.currentUser?.updateDisplayName(nickname);

      // 이메일 변경
      final currentEmail = FirebaseAuth.instance.currentUser?.email;
      if (email != currentEmail) {
        await FirebaseAuth.instance.currentUser?.verifyBeforeUpdateEmail(email);
      }

      // 비밀번호 변경
      if (password.isNotEmpty) {
        await FirebaseAuth.instance.currentUser?.updatePassword(password);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('프로필이 수정되었습니다'),
            backgroundColor: Color(0xFF7DE5C6),
          ),
        );
        Navigator.pop(context, true);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String msg = '수정 실패';
        if (e.code == 'requires-recent-login') {
          msg = '보안을 위해 재로그인 후 시도해주세요';
        } else if (e.code == 'email-already-in-use') {
          setState(() => _emailError = '이미 사용 중인 이메일입니다');
          setState(() => _isSaving = false);
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
        );
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
      if (mounted) setState(() => _isSaving = false);
    }
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
                      ? const Icon(Icons.check,
                          color: Color(0xFF53CDC3), size: 20)
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
  void dispose() {
    _nicknameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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
                      '프로필 수정',
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

          // ─── 폼 ───
          Expanded(
            child: _isLoading
                ? const Center(
                    child:
                        CircularProgressIndicator(color: Color(0xFF53CDC3)),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(35, 28, 35, 30),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 프로필 사진
                        Center(
                          child: GestureDetector(
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('미구현 기능입니다'),
                                  backgroundColor: Color(0xFF757680),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            },
                            child: Stack(
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF4F4F4),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFFBCBCBC),
                                      width: 1,
                                    ),
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.person,
                                      size: 40,
                                      color: Color(0xFFBCBCBC),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF53CDC3),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.camera_alt,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),

                        // 닉네임
                        _buildLabel('닉네임'),
                        const SizedBox(height: 4),
                        _buildInput(
                          controller: _nicknameController,
                          hint: '10자 이하로 입력해주세요',
                          error: _nicknameError,
                        ),
                        if (_nicknameError != null)
                          _buildError(_nicknameError!),
                        const SizedBox(height: 16),

                        // 이메일
                        _buildLabel('이메일'),
                        const SizedBox(height: 4),
                        _buildInput(
                          controller: _emailController,
                          hint: '이메일을 입력하세요',
                          error: _emailError,
                        ),
                        if (_emailError != null) _buildError(_emailError!),
                        const SizedBox(height: 16),

                        // 비밀번호
                        _buildLabel('비밀번호 변경 (선택)'),
                        const SizedBox(height: 4),
                        _buildInput(
                          controller: _passwordController,
                          hint: '새 비밀번호 (8자 이상)',
                          error: _passwordError,
                          obscureText: true,
                        ),
                        if (_passwordError != null)
                          _buildError(_passwordError!),
                        const SizedBox(height: 16),

                        // 학교
                        _buildLabel('학교'),
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: () => _showDropdownPicker(
                            title: '학교 선택',
                            options: _schoolOptions,
                            currentValue: _selectedSchool,
                            onSelected: (v) =>
                                setState(() => _selectedSchool = v),
                          ),
                          child: _buildDropdown(
                            value: _selectedSchool,
                            placeholder: '학교 선택',
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 학과
                        _buildLabel('학과'),
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: () => _showDropdownPicker(
                            title: '학과 선택',
                            options: _majorOptions,
                            currentValue: _selectedMajor,
                            onSelected: (v) =>
                                setState(() => _selectedMajor = v),
                          ),
                          child: _buildDropdown(
                            value: _selectedMajor,
                            placeholder: '학과 선택',
                          ),
                        ),
                        const SizedBox(height: 36),

                        // 저장 버튼
                        GestureDetector(
                          onTapDown: (_) =>
                              setState(() => _savePressed = true),
                          onTapUp: (_) {
                            setState(() => _savePressed = false);
                            if (!_isSaving) _save();
                          },
                          onTapCancel: () =>
                              setState(() => _savePressed = false),
                          child: AnimatedScale(
                            scale: _savePressed ? 0.96 : 1.0,
                            duration: const Duration(milliseconds: 100),
                            child: Container(
                              width: double.infinity,
                              height: 42,
                              decoration: BoxDecoration(
                                color: const Color(0xFF7DE5C6),
                                borderRadius: BorderRadius.circular(59),
                              ),
                              child: Center(
                                child: _isSaving
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        '저장',
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

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF4C4C4C),
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.50,
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String hint,
    String? error,
    bool obscureText = false,
  }) {
    return SizedBox(
      height: 40,
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
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: Color(0xFFD1D1D1), width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: error != null ? Colors.red : const Color(0xFFD1D1D1),
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: error != null ? Colors.red : const Color(0xFF53CDC3),
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown({String? value, required String placeholder}) {
    return Container(
      width: double.infinity,
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD1D1D1), width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              value ?? placeholder,
              style: TextStyle(
                color: value != null
                    ? const Color(0xFF141516)
                    : const Color(0xFF757680),
                fontSize: 12,
                fontWeight: FontWeight.w400,
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
    );
  }

  Widget _buildError(String text) {
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
