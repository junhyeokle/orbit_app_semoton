import 'package:flutter/material.dart';

class OrbitBottomNavBar extends StatefulWidget {
  final int currentIndex;

  const OrbitBottomNavBar({super.key, required this.currentIndex});

  @override
  State<OrbitBottomNavBar> createState() => _OrbitBottomNavBarState();
}

class _OrbitBottomNavBarState extends State<OrbitBottomNavBar> {
  int? _tappedIndex;

  static const _routes = ['/home', '/map', '/chat', '/profile'];
  static const _labels = ['홈', '맵', '채팅', '프로필'];
  static const _icons = [
    Icons.home_outlined,
    Icons.map_outlined,
    Icons.chat_bubble_outline,
    Icons.person_outline,
  ];
  static const _activeIcons = [
    Icons.home,
    Icons.map,
    Icons.chat_bubble,
    Icons.person,
  ];

  static const _activeColor = Color(0xFF141516);
  static const _inactiveColor = Color(0xFF757680);

  void _onTap(int index) {
    if (index == widget.currentIndex) return;

    setState(() => _tappedIndex = index);
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => _tappedIndex = null);
    });

    Navigator.pushReplacementNamed(context, _routes[index]);
  }

  @override
  Widget build(BuildContext context) {
    // [수정] 시스템 네비게이션바 높이를 포함하도록 동적 높이 계산
    // 고정 75px + 하단 시스템 바 높이 (갤럭시 등 제스처 바 / 버튼 바)
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      height: 75 + bottomPadding,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: const Color(0x1E000000),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      // [수정] SafeArea(top: false) → 하단 padding을 콘텐츠 영역에만 적용
      // Container 높이가 이미 bottom padding 포함 → 아이콘/텍스트가 시스템 바 위에 위치
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(4, (index) {
            final isActive = widget.currentIndex == index;
            final isTapped = _tappedIndex == index;
            final scale = isTapped ? 0.88 : 1.0;

            return Expanded(
              child: GestureDetector(
                onTap: () => _onTap(index),
                behavior: HitTestBehavior.opaque,
                child: AnimatedScale(
                  scale: scale,
                  duration: const Duration(milliseconds: 100),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isActive ? _activeIcons[index] : _icons[index],
                        size: 26,
                        color: isActive ? _activeColor : _inactiveColor,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _labels[index],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              isActive ? FontWeight.w500 : FontWeight.w300,
                          color: isActive ? _activeColor : _inactiveColor,
                          height: 1.50,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
