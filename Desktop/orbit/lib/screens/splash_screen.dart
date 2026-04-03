import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  bool _showTapHint = false;
  late AnimationController _dotController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // 도트 애니메이션
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    // "Tap anywhere to start !" fade-in/fade-out 반복
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );

    // 2초 후 로딩 완료 → 도트 멈추고, 탭 힌트 fade-in/out 시작
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _dotController.stop();
        setState(() {
          _isLoading = false;
          _showTapHint = true;
        });
        // fade-in → fade-out 반복
        _fadeController.repeat(reverse: true);
      }
    });
  }

  void _onTap() {
    if (_isLoading) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  void dispose() {
    _dotController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: GestureDetector(
        onTap: _onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: screenWidth,
          height: screenHeight,
          clipBehavior: Clip.antiAlias,
          decoration: const BoxDecoration(color: Colors.white),
          child: Stack(
            children: [
              // [수정] 앱 로고: logo.png 이미지 사용 (기존 아이콘 박스 교체)
              Positioned(
                left: (screenWidth - 78) / 2,
                top: screenHeight * 0.277,
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 78,
                  height: 78,
                  fit: BoxFit.contain,
                  // logo.png 없을 경우 기존 아이콘 박스로 폴백
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 78,
                    height: 78,
                    decoration: ShapeDecoration(
                      color: const Color(0xFF0C0F20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.auto_awesome,
                        color: Color(0xFF53CDC3),
                        size: 40,
                      ),
                    ),
                  ),
                ),
              ),

              // ORBIT 텍스트
              Positioned(
                left: 0,
                right: 0,
                top: screenHeight * 0.386,
                child: const Text(
                  'ORBIT',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF0C0F20),
                    fontSize: 36,
                    fontFamily: 'PretendardBlack', // [수정] PretendardBlack 폰트 적용
                    fontWeight: FontWeight.bold,
                    height: 1.50,
                    letterSpacing: 7.20,
                  ),
                ),
              ),

              // 캠퍼스 마이크로 협력 네트워크
              Positioned(
                left: 0,
                right: 0,
                top: screenHeight * 0.447,
                child: const Text(
                  '캠퍼스 마이크로 협력 네트워크',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF757680),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.50,
                  ),
                ),
              ),

              // 도트 3개 (로딩 중: 애니메이션 / 로딩 완료: 정적)
              Positioned(
                left: 0,
                right: 0,
                top: screenHeight * 0.826,
                child: _isLoading
                    ? AnimatedBuilder(
                        animation: _dotController,
                        builder: (context, child) {
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildAnimDot(0, const Color(0xFFD9D9D9)),
                              const SizedBox(width: 17),
                              _buildAnimDot(1, const Color(0xFFA5A5A5)),
                              const SizedBox(width: 17),
                              _buildAnimDot(2, const Color(0xFF707070)),
                            ],
                          );
                        },
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildStaticDot(const Color(0xFFD9D9D9)),
                          const SizedBox(width: 17),
                          _buildStaticDot(const Color(0xFFA5A5A5)),
                          const SizedBox(width: 17),
                          _buildStaticDot(const Color(0xFF707070)),
                        ],
                      ),
              ),

              // "Tap anywhere to start !" fade-in/out 반복
              if (_showTapHint)
                Positioned(
                  left: 0,
                  right: 0,
                  top: screenHeight * 0.897,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: const Text(
                      'Tap anywhere to start !',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF38D0A0),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.50,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimDot(int index, Color baseColor) {
    final delay = index * 0.3;
    final value = (_dotController.value - delay) % 1.0;
    final opacity = value < 0.5 ? value * 2 : (1.0 - value) * 2;
    return Container(
      width: 8,
      height: 8,
      decoration: ShapeDecoration(
        color: baseColor.withOpacity(opacity.clamp(0.3, 1.0)),
        shape: const OvalBorder(),
      ),
    );
  }

  Widget _buildStaticDot(Color color) {
    return Container(
      width: 8,
      height: 8,
      decoration: ShapeDecoration(
        color: color,
        shape: const OvalBorder(),
      ),
    );
  }
}
