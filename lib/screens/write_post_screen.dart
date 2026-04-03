import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/post_service.dart';
import '../services/campus_data.dart';
import '../models/post_model.dart';

class WritePostScreen extends StatefulWidget {
  const WritePostScreen({super.key});

  @override
  State<WritePostScreen> createState() => _WritePostScreenState();
}

class _WritePostScreenState extends State<WritePostScreen> {
  final PostService _postService = PostService();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _pointController = TextEditingController();

  String? _selectedBuilding; // 건물 선택 (좌표 변환용)
  bool _isLoading = false;
  int _myPoint = 0;

  @override
  void initState() {
    super.initState();
    _loadMyPoint();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _pointController.dispose();
    super.dispose();
  }

  Future<void> _loadMyPoint() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (doc.exists && mounted) {
        setState(() {
          _myPoint = doc.data()?['point'] ?? 0;
        });
      }
    } catch (_) {}
  }

  void _useAllPoints() {
    setState(() {
      _pointController.text = _myPoint.toString();
    });
  }

  String _formatPoint(int point) {
    if (point >= 1000) {
      final str = point.toString();
      final buffer = StringBuffer();
      for (int i = 0; i < str.length; i++) {
        if (i > 0 && (str.length - i) % 3 == 0) buffer.write(',');
        buffer.write(str[i]);
      }
      return buffer.toString();
    }
    return point.toString();
  }

  void _showBuildingSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '건물 선택',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF141516),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close, color: Color(0xFF757680)),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: CampusDataService.buildings.length,
                  itemBuilder: (context, index) {
                    final building = CampusDataService.buildings[index];
                    final isSelected = _selectedBuilding == building.name;
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _selectedBuilding = building.name;
                        });
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        color: isSelected
                            ? const Color(0xFFF0FBF9)
                            : Colors.transparent,
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected
                                    ? const Color(0xFF53CDC3)
                                    : const Color(0xFFD1D1D1),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              building.name,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: isSelected
                                    ? const Color(0xFF53CDC3)
                                    : const Color(0xFF4C4C4C),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submitPost() async {
    // Validation
    if (_titleController.text.isEmpty) {
      _showError('제목을 입력해주세요');
      return;
    }
    if (_contentController.text.isEmpty) {
      _showError('요청사항을 입력해주세요');
      return;
    }
    if (_selectedBuilding == null) {
      _showError('건물을 선택해주세요');
      return;
    }
    if (_pointController.text.isEmpty) {
      _showError('리워드 포인트를 입력해주세요');
      return;
    }

    final point = int.tryParse(_pointController.text);
    if (point == null || point < 0) {
      _showError('리워드 포인트는 0 이상이어야 합니다');
      return;
    }
    if (point > _myPoint) {
      _showError('보유 포인트가 부족합니다');
      return;
    }

    // 선택된 건물의 좌표 가져오기
    final building = CampusDataService.findByName(_selectedBuilding!);
    if (building == null) {
      _showError('건물 정보를 찾을 수 없습니다');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

      // 서버 DTO: userId, title, content, latitude, longitude, rewardPoint
      final dto = PostCreateReqDto(
        userId: uid,
        title: _titleController.text,
        content: _contentController.text,
        latitude: building.latitude,
        longitude: building.longitude,
        rewardPoint: point,
      );

      final postId = await _postService.createPost(dto);

      if (!mounted) return;

      if (postId != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('게시물이 작성되었습니다'),
            backgroundColor: Color(0xFF53CDC3),
          ),
        );
        Navigator.pop(context, true);
      } else {
        _showError('게시물 작성에 실패했습니다');
      }
    } catch (e) {
      if (mounted) {
        _showError('오류 발생: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
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
                      '글쓰기',
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

          // ─── 콘텐츠 ───
          Expanded(
            child: SingleChildScrollView(
              // [수정] 하단 시스템 네비게이션바 가림 방지 - MediaQuery bottom padding 적용
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── 제목 ───
                  Container(
                    width: double.infinity,
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
                    child: TextField(
                      controller: _titleController,
                      style: const TextStyle(
                        color: Color(0xFF141516),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: const InputDecoration(
                        hintText: '제목을 입력해주세요',
                        hintStyle: TextStyle(
                          color: Color(0xFFBCBCBC),
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      maxLines: 1,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ─── 요청사항 ───
                  Container(
                    width: double.infinity,
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '요청사항',
                          style: TextStyle(
                            color: Color(0xFF141516),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFE8E8E8),
                            ),
                          ),
                          child: TextField(
                            controller: _contentController,
                            style: const TextStyle(
                              color: Color(0xFF141516),
                              fontSize: 14,
                              height: 1.5,
                            ),
                            decoration: const InputDecoration(
                              hintText: '요청 내용을 자세히 작성해주세요',
                              hintStyle: TextStyle(
                                color: Color(0xFFBCBCBC),
                                fontSize: 14,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                            ),
                            maxLines: 5,
                            minLines: 5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ─── 위치 (건물 선택 → 좌표 변환) ───
                  Container(
                    width: double.infinity,
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '위치',
                          style: TextStyle(
                            color: Color(0xFF141516),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // 건물 선택
                        _buildLocationSelector(
                          label: '건물',
                          value: _selectedBuilding,
                          onTap: _showBuildingSelector,
                        ),

                        const SizedBox(height: 14),

                        // 지도 미리보기 영역
                        Container(
                          width: double.infinity,
                          height: 150,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1C2E),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: _selectedBuilding != null
                              ? _buildMapPreview()
                              : Center(
                                  child: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.map_outlined,
                                        color:
                                            Colors.white.withOpacity(0.4),
                                        size: 36,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '건물을 선택하면 지도가 표시됩니다',
                                        style: TextStyle(
                                          color: Colors.white
                                              .withOpacity(0.5),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ─── 리워드 ───
                  Container(
                    width: double.infinity,
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              '리워드',
                              style: TextStyle(
                                color: Color(0xFF141516),
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '보유 ${_formatPoint(_myPoint)} P',
                              style: const TextStyle(
                                color: Color(0xFF53CDC3),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F5F5),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFE8E8E8),
                                  ),
                                ),
                                child: TextField(
                                  controller: _pointController,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(
                                    color: Color(0xFF141516),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  decoration: const InputDecoration(
                                    hintText: '포인트 입력',
                                    hintStyle: TextStyle(
                                      color: Color(0xFFBCBCBC),
                                      fontSize: 14,
                                    ),
                                    suffixText: 'P',
                                    suffixStyle: TextStyle(
                                      color: Color(0xFF53CDC3),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: _useAllPoints,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF53CDC3),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  '전액 사용',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          '* 요청 완료 시 수행자에게 포인트가 전달됩니다',
                          style: TextStyle(
                            color: Color(0xFFA5A5AC),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ─── 업로드 버튼 ───
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: GestureDetector(
                      onTap: _isLoading ? null : _submitPost,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: double.infinity,
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: _isLoading
                              ? null
                              : const LinearGradient(
                                  colors: [
                                    Color(0xFF53CDC3),
                                    Color(0xFF7DE5C6),
                                  ],
                                ),
                          color: _isLoading ? const Color(0xFFBCBCBC) : null,
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: _isLoading
                              ? []
                              : [
                                  BoxShadow(
                                    color: const Color(0xFF53CDC3)
                                        .withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                        ),
                        child: Center(
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  '업로드 하기',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
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

  /// 건물 선택 시 GoogleMap 미리보기 (터치 비활성화, 고정 카메라)
  Widget _buildMapPreview() {
    final building = CampusDataService.findByName(_selectedBuilding!);
    if (building == null) {
      return Center(
        child: Text(
          '건물 정보를 찾을 수 없습니다',
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 12,
          ),
        ),
      );
    }

    final target = LatLng(building.latitude, building.longitude);

    return IgnorePointer(
      child: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: target,
          zoom: 17.0,
        ),
        // [수정] 빨간 Marker 표시 (건물 위치 표시용)
        markers: {
          Marker(
            markerId: const MarkerId('selected_building'),
            position: target,
          ),
        },
        zoomGesturesEnabled: false,
        scrollGesturesEnabled: false,
        rotateGesturesEnabled: false,
        tiltGesturesEnabled: false,
        zoomControlsEnabled: false,
        myLocationEnabled: false,
        myLocationButtonEnabled: false,
        mapToolbarEnabled: false,
        liteModeEnabled: true,
      ),
    );
  }

  Widget _buildLocationSelector({
    required String label,
    required String? value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: value != null
                ? const Color(0xFF53CDC3).withOpacity(0.3)
                : const Color(0xFFE8E8E8),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: value != null
                    ? const Color(0xFF53CDC3)
                    : const Color(0xFFD1D1D1),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                value ?? '$label을 선택해주세요',
                style: TextStyle(
                  color: value != null
                      ? const Color(0xFF141516)
                      : const Color(0xFFBCBCBC),
                  fontSize: 14,
                  fontWeight: value != null ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
            ),
            GestureDetector(
              onTap: onTap,
              child: Text(
                value != null ? '변경' : '선택',
                style: const TextStyle(
                  color: Color(0xFF53CDC3),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
