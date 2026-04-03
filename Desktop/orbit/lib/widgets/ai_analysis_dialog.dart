import 'package:flutter/material.dart';
import '../services/ai_analysis_service.dart';
import '../models/post_model.dart';

/// AI 분석 팝업 다이얼로그
/// - 분석 진행 연출 (단계별 메시지 + 프로그레스)
/// - 결과 fade-in 표시
class AiAnalysisDialog extends StatefulWidget {
  final PostResDto post;
  final double? userLat;
  final double? userLng;

  const AiAnalysisDialog({
    super.key,
    required this.post,
    this.userLat,
    this.userLng,
  });

  @override
  State<AiAnalysisDialog> createState() => _AiAnalysisDialogState();
}

class _AiAnalysisDialogState extends State<AiAnalysisDialog> {
  // 분석 연출 상태
  bool _isAnalyzing = true;
  int _currentStep = 0;
  AiAnalysisResult? _result;

  // 분석 단계 메시지
  static const _analysisSteps = [
    '게시글을 분석하는 중입니다...',
    '핵심 정보를 추출하는 중...',
    '위치 정보를 계산하는 중...',
    '요청의 난이도를 평가하는 중...',
    '최적의 판단을 생성하는 중...',
  ];

  @override
  void initState() {
    super.initState();
    _startAnalysis();
  }

  Future<void> _startAnalysis() async {
    // ─── 분석 연출: 0.6초 간격으로 단계 메시지 변경 ───
    for (int i = 0; i < _analysisSteps.length; i++) {
      if (!mounted) return;
      setState(() => _currentStep = i);
      await Future.delayed(const Duration(milliseconds: 600));
    }

    // ─── 실제 분석 실행 ───
    final service = AiAnalysisService();
    final result = service.enhanceAiResult(
      widget.post,
      userLat: widget.userLat,
      userLng: widget.userLng,
    );

    if (mounted) {
      setState(() {
        _result = result;
        _isAnalyzing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380),
        decoration: BoxDecoration(
          color: const Color(0xFF0C0E1F),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF53CDC3).withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF53CDC3).withOpacity(0.1),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: _isAnalyzing ? _buildAnalyzingView() : _buildResultView(),
      ),
    );
  }

  // ═══════════════════════════════════════
  // 분석 중 연출 UI
  // ═══════════════════════════════════════
  Widget _buildAnalyzingView() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // AI 아이콘
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF53CDC3),
                  const Color(0xFF53CDC3).withOpacity(0.6),
                ],
              ),
            ),
            child: const Icon(
              Icons.psychology,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 24),

          // 타이틀
          const Text(
            'AI 분석 중',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),

          // 프로그레스 인디케이터
          const SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Color(0xFF53CDC3),
            ),
          ),
          const SizedBox(height: 20),

          // 단계 메시지 (애니메이션)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              _analysisSteps[_currentStep],
              key: ValueKey(_currentStep),
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 12),

          // 프로그레스 바
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_currentStep + 1) / _analysisSteps.length,
              backgroundColor: Colors.white.withOpacity(0.1),
              color: const Color(0xFF53CDC3),
              minHeight: 3,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════
  // 분석 결과 UI (fade-in)
  // ═══════════════════════════════════════
  Widget _buildResultView() {
    final r = _result!;

    return AnimatedOpacity(
      opacity: _isAnalyzing ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 500),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── 헤더 ───
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF53CDC3),
                  ),
                  child: const Icon(Icons.psychology, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                const Text(
                  'AI 분석 결과',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ─── 점수 카드 ───
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF53CDC3).withOpacity(0.15),
                    const Color(0xFF53CDC3).withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF53CDC3).withOpacity(0.3),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    '${r.score}점',
                    style: const TextStyle(
                      color: Color(0xFF53CDC3),
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                    decoration: BoxDecoration(
                      color: _difficultyColor(r.difficulty).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '난이도: ${r.difficulty}',
                      style: TextStyle(
                        color: _difficultyColor(r.difficulty),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // ─── 분석 상세 항목 ───
            _buildInfoRow('📦', '물건', r.object.isEmpty ? '기타 물건' : r.object),
            // [수정] 경로 제거 → 게시물 위치(목적지)만 표시
            _buildInfoRow('📍', '목적지', r.fromLocation.isEmpty ? '캠퍼스 내' : r.fromLocation),
            _buildInfoRow('⚡', '긴급도', r.urgency.isEmpty ? '보통' : r.urgency),
            _buildInfoRow('📏', '거리', r.distance.isEmpty ? '알 수 없음' : r.distance),

            const SizedBox(height: 18),

            // ─── AI 조언 ───
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('💡', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Text(
                        'AI 조언',
                        style: TextStyle(
                          color: const Color(0xFF53CDC3),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    r.advice,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 13,
                      height: 1.55,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // ─── 닫기 버튼 ───
            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF53CDC3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  '확인',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 정보 행 위젯 ───
  Widget _buildInfoRow(String emoji, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _difficultyColor(String difficulty) {
    switch (difficulty) {
      case '쉬움': return const Color(0xFF4CAF50);
      case '보통': return const Color(0xFFFFA726);
      case '다소 어려움': return const Color(0xFFEF5350);
      case '어려움': return const Color(0xFFD32F2F);
      default: return const Color(0xFF53CDC3);
    }
  }
}
