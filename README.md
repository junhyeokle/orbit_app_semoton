# ORBIT 🚀

ORBIT은 위치 기반으로 사용자 간 요청을 연결해주는 커뮤니티 플랫폼입니다.

사용자는 주변에서 필요한 도움(배달, 대여, 간단한 요청 등)을 게시물 형태로 올릴 수 있고,  
다른 사용자는 이를 확인하고 수락하여 수행한 뒤 보상을 받는 구조입니다.

이 앱은 단순 커뮤니티를 넘어  
**위치 + 실시간 매칭 + 채팅 + AI 분석**을 결합한 서비스입니다.

---

## 💡 핵심 컨셉

- “근처 사람에게 빠르게 도움을 요청하고 해결한다”
- 오프라인 기반 문제를 온라인 매칭으로 해결
- 즉시성 + 실용성 중심 서비스

---

## ⚡ 주요 특징

### 📍 위치 기반 서비스
- 사용자 위치 기반으로 주변 요청 확인
- 지도에서 건물 단위로 게시물 탐색

### 🤝 실시간 매칭
- 요청 수락 시 즉시 매칭
- 수행자와 요청자 연결

### 💬 채팅 시스템
- 매칭된 사용자 간 실시간 채팅
- 요청 수행 과정 커뮤니케이션

### 💰 보상 시스템
- 요청 완료 시 포인트 지급
- 간단한 경제 구조 형성

### 🤖 AI 분석 기능
- 게시물 내용을 분석하여
  - 요청 유형 (배달 / 대여 등)
  - 목적지
  - 긴급도
  자동 추출

---

## 🎯 목표

- 대학 캠퍼스 및 특정 지역 기반에서 빠른 문제 해결
- 소규모 지역 커뮤니티 활성화
- 실생활 밀착형 서비스 제공

---

# ORBIT 프론트엔드 구조

> ORBIT — 경희대학교 국제캠퍼스 위치 기반 마이크로 협력 네트워크

## 기술 스택

| 구분 | 기술 |
|------|------|
| 프레임워크 | Flutter 3.x (Dart) |
| 인증 | Firebase Authentication |
| 데이터베이스 | Cloud Firestore (채팅/위치), Spring Boot REST API (게시물/유저) |
| 지도 | Google Maps Flutter |
| 위치 | Geolocator |
| 상태 관리 | setState 기반 (별도 상태관리 라이브러리 미사용) |

## 디렉토리 구조

```
lib/
├── main.dart
├── models/
│   ├── chat_room_model.dart
│   ├── post_model.dart
│   └── user_model.dart
├── screens/
│   ├── splash_screen.dart
│   ├── login_screen.dart
│   ├── signup_screen.dart
│   ├── home_screen.dart
│   ├── map_screen.dart
│   ├── chat_list_screen.dart
│   ├── chat_screen.dart
│   ├── write_post_screen.dart
│   ├── post_detail_screen.dart
│   ├── my_activities_screen.dart
│   ├── profile_screen.dart
│   └── profile_edit_screen.dart
├── services/
│   ├── api_service.dart
│   ├── auth_service.dart
│   ├── chat_service.dart
│   ├── post_service.dart
│   ├── location_service.dart
│   ├── ai_analysis_service.dart
│   └── campus_data.dart
└── widgets/
    ├── ai_analysis_dialog.dart
    └── bottom_nav_bar.dart
```

## 엔트리 포인트

### `main.dart`

앱 시작점으로 Firebase 초기화를 수행하고, Material 3 기반 테마(민트 컬러 `#53CDC3`)와 전체 화면 라우팅을 설정한다. Named route 방식으로 `/splash`, `/login`, `/signup`, `/home` 등의 경로를 정의한다.

## models/ — 데이터 모델

| 파일 | 주요 클래스 | 설명 |
|------|-------------|------|
| `chat_room_model.dart` | `ChatRoomModel`, `MessageModel` | Firestore 채팅방 문서와 메시지 문서를 Dart 객체로 변환한다. 채팅방은 참여자, 닉네임, 마지막 메시지 정보를 포함하고, 메시지는 발신자, 텍스트, 읽음 여부(`read`), 시스템 메시지 여부를 포함한다. |
| `post_model.dart` | `PostCreateReqDto`, `PostResDto`, `PostAcceptReqDto` | REST API와 통신하기 위한 게시물 DTO 모음이다. 생성 요청, 응답 파싱, 수락 요청을 처리하며, 다양한 타임스탬프 및 좌표 형식에 대한 파싱 유틸리티를 포함한다. |
| `user_model.dart` | `UserResDto`, `UserLocationResDto`, `UserLocationUpdateReqDto` | 유저 프로필(닉네임, 학교, 학과, 포인트)과 위치 데이터를 정의한다. 활성 유저 판별 및 위치 동기화에 사용된다. |

## screens/ — 화면 UI

### 인증 흐름

| 파일 | 화면 | 설명 |
|------|------|------|
| `splash_screen.dart` | 스플래시 | 앱 로고와 로딩 애니메이션을 표시한 뒤 로그인 상태에 따라 홈 또는 로그인 화면으로 분기한다. 도트 애니메이션과 "Tap anywhere to start" 페이드 효과를 포함한다. |
| `login_screen.dart` | 로그인 | 아이디/비밀번호 입력 필드, 로그인 버튼, Google 소셜 로그인을 제공한다. Firebase Auth를 통해 인증을 처리하며 에러별 분기 메시지를 표시한다. |
| `signup_screen.dart` | 회원가입 | 이메일 도메인 선택, 학교/학과 드롭다운, 비밀번호/닉네임 검증을 포함하는 종합 가입 폼이다. Firebase 유저 생성 후 Firestore에 프로필을 저장한다. |

### 메인 탭 화면

| 파일 | 화면 | 설명 |
|------|------|------|
| `home_screen.dart` | 홈 (요청 목록) | 전체 게시물 피드를 거리순/보상순/최신순으로 정렬하여 표시한다. GPS 위치를 기반으로 각 게시물까지의 거리를 계산하며, 새 게시물 작성 FAB과 새로고침 기능을 제공한다. |
| `map_screen.dart` | 지도 | Google Maps 위에 캠퍼스 건물별 사용자 수와 게시물 수를 원형 마커로 시각화한다. Haversine 공식으로 건물 반경 내 인원을 계산하며, 건물 검색과 현재 위치 이동 기능을 포함한다. |
| `chat_list_screen.dart` | 채팅 목록 | 참여 중인 채팅방 목록을 표시하며 각 방의 안 읽은 메시지 수를 배지로 보여준다. AppBar 새로고침 버튼으로 목록을 갱신한다. |
| `profile_screen.dart` | 프로필 | 유저 아바타, 닉네임, 학교 정보, 보유 포인트를 카드 형태로 표시한다. 내 활동, 보상, 프로필 수정, 로그아웃 메뉴를 제공한다. |

### 상세/기능 화면

| 파일 | 화면 | 설명 |
|------|------|------|
| `chat_screen.dart` | 채팅 | Firestore `snapshots()` 기반 StreamBuilder로 메시지를 실시간 수신한다. 개별 메시지의 `read` 필드를 기반으로 읽음 표시('1')를 실시간 동기화하며, 상대방이 읽으면 즉시 UI가 갱신된다. |
| `write_post_screen.dart` | 게시물 작성 | 건물 위치 선택(지도 프리뷰), 보상 포인트 설정, 제목/내용 입력 폼을 제공한다. 현재 보유 포인트를 표시하고 API를 통해 게시물을 등록한다. |
| `post_detail_screen.dart` | 게시물 상세 | 작성자 정보, 위치 지도 프리뷰, 보상 포인트, AI 분석 기능을 포함한 상세 화면이다. 게시물 수락 및 완료 처리를 Firestore 직접 업데이트로 수행하며, 채팅 연결 기능을 제공한다. |
| `my_activities_screen.dart` | 내 활동 | 본인이 작성한 게시물을 상태 배지(완료/진행중)와 함께 최신순으로 표시한다. |
| `profile_edit_screen.dart` | 프로필 수정 | 닉네임, 이메일, 비밀번호, 학교, 학과 수정 폼을 제공하며 Firebase Auth 및 Firestore에 변경사항을 반영한다. |

## services/ — 비즈니스 로직

| 파일 | 주요 클래스 | 설명 |
|------|-------------|------|
| `api_service.dart` | `ApiService` | Spring Boot REST API(`http://52.79.112.27:8080`)와 통신하는 HTTP 클라이언트다. Firebase ID Token 기반 Bearer 인증을 사용하며, 게시물 CRUD, 유저 프로필 조회, 위치 동기화, AI 분석 요청을 처리한다. |
| `auth_service.dart` | `AuthService` | Firebase Auth를 통한 로그인/회원가입/로그아웃을 관리한다. 아이디 기반 로그인(Firestore에서 이메일 조회 후 Auth 로그인)과 Google Sign-In을 지원한다. |
| `chat_service.dart` | `ChatService` | Firestore `chats` 컬렉션 기반 채팅 서비스다. 채팅방 목록/생성, 메시지 전송, 읽음 처리를 담당한다. 메시지 목록은 `snapshots()` 실시간 스트림을 제공하고(채팅 화면 전용), 나머지는 1회성 `get()` 조회로 Firestore 비용을 절감한다. |
| `post_service.dart` | `PostService` | `ApiService`를 래핑하는 상위 서비스 레이어로, 게시물 생성/조회/수락/완료/AI 분석 결과 조회를 위한 간결한 인터페이스를 제공한다. |
| `location_service.dart` | `LocationService` | GPS 위치 획득, 권한 처리, 건물별 유저/게시물 수 계산, 서버 위치 동기화를 담당한다. 1회성 위치 조회 방식으로 동작한다. |
| `ai_analysis_service.dart` | `AiAnalysisService` | 게시물 내용에서 물건/카테고리/장소/긴급도를 추출하고, 매칭 점수(0~100)와 난이도를 산정한다. 거리, 물건 유형, 보상 기반의 맞춤형 AI 조언을 생성한다. |
| `campus_data.dart` | `CampusDataService` | 경희대 국제캠퍼스 15개 건물의 좌표, 반경 정보를 정적 데이터로 관리한다. Haversine 공식 기반 거리 계산과 건물 검색 유틸리티를 제공한다. |

## widgets/ — 공통 위젯

| 파일 | 주요 클래스 | 설명 |
|------|-------------|------|
| `ai_analysis_dialog.dart` | `AiAnalysisDialog` | AI 분석 결과를 표시하는 모달 다이얼로그다. 분석 중 단계별 애니메이션을 보여주고, 완료 후 점수/난이도 배지, 분석 상세(물건, 장소, 긴급도, 거리), AI 조언을 표시한다. |
| `bottom_nav_bar.dart` | `OrbitBottomNavBar` | 홈/지도/채팅/프로필 4개 탭을 가진 커스텀 하단 네비게이션 바다. 탭 시 스케일 애니메이션을 적용하며, 시스템 네비게이션 바 높이를 고려한 동적 높이 조정과 라우트 기반 화면 전환을 수행한다. |

## 데이터 흐름

```
┌─────────────────────────────────────────────────┐
│                   screens/                       │
│  (UI Layer - setState 기반 상태 관리)              │
└────────────┬──────────────────┬──────────────────┘
             │                  │
     ┌───────▼───────┐  ┌──────▼───────┐
     │  services/     │  │  Firestore   │
     │  (API 통신)    │  │  (실시간 채팅) │
     └───────┬───────┘  └──────┬───────┘
             │                  │
     ┌───────▼───────┐  ┌──────▼───────┐
     │  Spring Boot  │  │  Firebase    │
     │  REST API     │  │  Cloud       │
     │  (게시물/유저) │  │  (채팅/위치)  │
     └───────────────┘  └──────────────┘
```

**Firestore 비용 최적화 전략**: 채팅 메시지를 제외한 모든 Firestore 조회는 `get()`(1회성)으로 처리하고, `initState` 자동 로딩 + 수동 새로고침 버튼으로 데이터를 갱신한다. 채팅 메시지만 `snapshots()` 실시간 스트림을 사용하여 읽음 처리를 즉시 동기화한다.

## 네비게이션 구조

```
SplashScreen
  ├── (로그인됨) → HomeScreen ← BottomNavBar
  │                  ├── [홈]     HomeScreen
  │                  ├── [지도]   MapScreen
  │                  ├── [채팅]   ChatListScreen → ChatScreen
  │                  └── [프로필] ProfileScreen
  │                                 ├── MyActivitiesScreen
  │                                 └── ProfileEditScreen
  │
  └── (비로그인) → LoginScreen
                     └── SignupScreen
```

게시물 관련 화면은 `Navigator.push`로 스택에 쌓이며, 인증 관련 전환은 `Navigator.pushReplacementNamed`로 스택을 교체한다.
