import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/bottom_nav_bar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  Map<String, dynamic>? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _authService.getFirestoreProfile();
      if (mounted) {
        setState(() {
          _profile = profile;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '로그아웃',
          style: TextStyle(color: Color(0xFF141516), fontWeight: FontWeight.w700),
        ),
        content: const Text(
          '정말 로그아웃하시겠습니까?',
          style: TextStyle(color: Color(0xFF4C4C4C)),
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
              '로그아웃',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _authService.signOut();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  void _showNotImplemented() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('미구현 기능입니다'),
        duration: Duration(seconds: 1),
        backgroundColor: Color(0xFF757680),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nickname = _profile?['nickname'] ?? '닉네임';
    final school = _profile?['school'] ?? '';
    final department = _profile?['department'] ?? '';
    final point = _profile?['point'] ?? 0;
    final schoolInfo = [school, department].where((s) => s.isNotEmpty).join(' ');

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: Column(
        children: [
          // ─── 상단 헤더 ───
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
                padding: const EdgeInsets.fromLTRB(18, 12, 20, 16),
                child: const Text(
                  '프로필',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
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
                : RefreshIndicator(
                    color: const Color(0xFF53CDC3),
                    onRefresh: _loadProfile,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        children: [
                          // ─── 프로필 카드 ───
                          Container(
                            width: double.infinity,
                            color: Colors.white,
                            padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
                            child: Row(
                              children: [
                                // 프로필 사진
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF4F4F4),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFFBCBCBC),
                                      width: 1,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      nickname.isNotEmpty
                                          ? nickname[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF757680),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // 닉네임 + 학교
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        nickname,
                                        style: const TextStyle(
                                          color: Colors.black,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          height: 1.25,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        schoolInfo.isNotEmpty
                                            ? schoolInfo
                                            : '학교 정보 없음',
                                        style: const TextStyle(
                                          color: Color(0xFF8C8C8C),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w400,
                                          height: 1.33,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // 수정 아이콘
                                GestureDetector(
                                  onTap: () async {
                                    final result = await Navigator.pushNamed(
                                      context,
                                      '/profile_edit',
                                    );
                                    if (result == true) {
                                      _loadProfile();
                                    }
                                  },
                                  child: const Icon(
                                    Icons.edit_outlined,
                                    color: Color(0xFF8C8C8C),
                                    size: 18,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),

                          // ─── 포인트 카드 ───
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 28),
                            child: Container(
                              width: double.infinity,
                              height: 41,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    Color(0xFF53CDC3),
                                    Color(0xFF7DE5C6),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(26),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    '나의 POINT',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      height: 1.50,
                                    ),
                                  ),
                                  // [수정] 포인트 숫자 왼쪽에 diamonds.png 추가
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Image.asset(
                                        'assets/images/diamonds.png',
                                        width: 20,
                                        height: 20,
                                        fit: BoxFit.contain,
                                        errorBuilder: (context, error, stackTrace) =>
                                            const SizedBox.shrink(),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _formatPoint(point is int ? point : 0),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          height: 1.50,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // ─── 나의 활동 / 리워드 내역 ───
                          Container(
                            width: double.infinity,
                            color: Colors.white,
                            child: Column(
                              children: [
                                // [수정] 나의 활동: human.png 아이콘 추가
                                _buildMenuItemWithIcon(
                                  '나의 활동',
                                  iconPath: 'assets/images/human.png',
                                  bold: true,
                                  onTap: () {
                                    Navigator.pushNamed(
                                        context, '/my_activities');
                                  },
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20),
                                  child: Divider(
                                    height: 1,
                                    color: const Color(0xFFF0F0F0),
                                  ),
                                ),
                                // [수정] 리워드 내역: diamonds.png 아이콘으로 변경
                                _buildMenuItemWithIcon(
                                  '리워드 내역',
                                  iconPath: 'assets/images/diamonds.png',
                                  bold: true,
                                  onTap: _showNotImplemented,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),

                          // ─── 설정 메뉴 ───
                          Container(
                            width: double.infinity,
                            color: Colors.white,
                            child: Column(
                              children: [
                                _buildMenuItem(
                                  '다크모드',
                                  onTap: _showNotImplemented,
                                ),
                                _buildMenuDivider(),
                                _buildMenuItem(
                                  '알림',
                                  onTap: _showNotImplemented,
                                ),
                                _buildMenuDivider(),
                                _buildMenuItem(
                                  '데이터 및 저장공간',
                                  onTap: _showNotImplemented,
                                ),
                                _buildMenuDivider(),
                                _buildMenuItem(
                                  '고객센터',
                                  onTap: _showNotImplemented,
                                ),
                                _buildMenuDivider(),
                                _buildMenuItem(
                                  '로그아웃',
                                  onTap: _logout,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: const OrbitBottomNavBar(currentIndex: 3),
    );
  }

  Widget _buildMenuItem(
    String title, {
    bool bold = false,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: bold ? 64 : 35,
          vertical: 14,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: bold
                      ? const Color(0xFF4C4D53)
                      : const Color(0xFF757680),
                  fontSize: bold ? 15 : 14,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                  height: bold ? 1.60 : 1.50,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: const Color(0xFFBCBCBC),
            ),
          ],
        ),
      ),
    );
  }

  // [추가] 아이콘 포함 메뉴 아이템 (나의 활동, 리워드 내역 전용)
  Widget _buildMenuItemWithIcon(
    String title, {
    required String iconPath,
    bool bold = false,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 35, vertical: 14),
        child: Row(
          children: [
            // [추가] 아이콘 이미지
            Image.asset(
              iconPath,
              width: 22,
              height: 22,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) =>
                  const SizedBox(width: 22, height: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: bold
                      ? const Color(0xFF4C4D53)
                      : const Color(0xFF757680),
                  fontSize: bold ? 15 : 14,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                  height: bold ? 1.60 : 1.50,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: const Color(0xFFBCBCBC),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Divider(height: 1, color: const Color(0xFFF0F0F0)),
    );
  }
}
