import 'api_service.dart';
import '../models/post_model.dart';

/// REST API 기반 게시물 서비스
/// rewardPoint는 서버에서 직접 관리 (PostCreateReqDto, PostResDto에 포함)
class PostService {
  final ApiService _api = ApiService();

  /// 전체 게시물 가져오기
  Future<List<PostResDto>> getAllPosts() async {
    return await _api.getAllPosts();
  }

  /// 게시물 상세 조회
  Future<PostResDto?> getPostDetail(String postId) async {
    return await _api.getPostDetail(postId);
  }

  /// 게시물 작성
  Future<String?> createPost(PostCreateReqDto dto) async {
    return await _api.createPost(dto);
  }

  /// 게시물 수락
  Future<bool> acceptPost(String postId) async {
    return await _api.acceptPost(postId);
  }

  // [추가] 게시물 완료(종료) 처리
  Future<bool> completePost(String postId) async {
    return await _api.completePost(postId);
  }

  /// AI 분석 결과 조회
  Future<Map<String, dynamic>?> getAiResult(String postId) async {
    return await _api.getAiResult(postId);
  }
}
