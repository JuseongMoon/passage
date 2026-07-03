# ROADMAP — Passage

> 우선순위 기반. 각 Phase는 **end-to-end로 동작**하는 것을 완료 기준으로 한다(빌드+실데이터 검증).
> 상세 근거는 `Docs/DECISIONS.md`, 제품 범위는 `Docs/PRD.md`.

---

## Phase 0 — 기반 (Foundations)
프로젝트가 실제로 서게 만드는 토대. 기능 전에 이것부터.
- [x] `.gitignore` · `Config/*.xcconfig` · `Secrets.xcconfig`(gitignored)
- [x] 데이터 모델(Book · ReadingSession · Place) + `SchemaV1` + `MigrationPlan`
- [x] `ModelContainer`(CloudKit private + 로컬 폴백) · 앱 진입점 정리(템플릿 제거)
- [x] DesignSystem 토큰(Theme: Spacing · Radius · card 재질) — Color/Typography는 UI 작업 시 확장
- [x] `AppDependencies`(DI) + Root `TabView` 골격(서재 · 저널 · 설정) — 시뮬레이터 실행·렌더 검증 완료
- [x] 서비스 프로토콜 + 구현/스텁(Naver REST · Location · ImageStore · Auth더미 · BookSearch스텁)
- [x] Swift 6 language mode 전환 · 시뮬레이터 빌드 그린
- [x] Info.plist 네이버 키·위치 권한 · entitlements CloudKit 컨테이너 id (파일 반영)
- [ ] **Xcode UI 필요(남음)**: Config/*.xcconfig를 Debug/Release 구성에 지정 · SPM(NMapsMap 3.21.0) 추가 · CloudKit capability 활성화(컨테이너 등록) (→ ARCHITECTURE 부록 A)

## Phase 1 — MVP 핵심
순서는 데이터 흐름을 따른다: **책 → 세션 → 장소 → 회상**.

### 1a. Book
- [x] 수동 등록(제목/저자/ISBN/페이지) · 책 상세(세션 파생 통계) · Library 목록/카드 — 빌드·데이터 테스트·실행 검증 완료
- [ ] 검색 등록(`BookSearchService`, MVP: Google Books) · ISBN 조회 · 표지 표시
- [ ] 책 삭제/편집 · 표지 이미지

### 1b. Reading Session (Source of Truth)
- [x] `ReadingSessionController`: Start/Stop/Cancel · 활성 세션 즉시 저장 · **앱 재시작 시 복원** — 로직 테스트 4종 통과
- [x] 읽는 중 화면(TimelineView 경과 시간) · 전역 fullScreenCover로 표시
- [x] 종료 페이지(선택) 입력 — 시작 페이지 입력 UI는 후속
- [ ] 장소 질문 연결은 1c에서

### 1c. Place — "어디서 읽으셨나요?"
- [ ] 종료 직후 장소 프롬프트: 기존 선택 / 새로 생성
- [ ] `NaverMapView`(UIViewRepresentable) 지점 선택 · `LocationService` 현재 위치(선택)
- [ ] `NaverMapService` reverse-geocode로 주소 자동 채움
- [ ] 사진 첨부(`LocalImageStore`, 로컬 저장) · 장소 이름 지정
- [ ] → 세션에 book·place·시간 연결하여 **기억 저장 완료**

### 1d. Library & Journal (회상)
- [ ] Library: 책별 **총 독서시간 · 세션 수 · 읽은 장소** (세션에서 집계)
- [ ] Journal **Book View**(책 중심) · **Place View**(장소 중심) 타임라인
- [ ] Memory 상세(책·장소·시간·페이지·사진)

### 1e. 마감
- [ ] Settings + **Sign in with Apple 더미 버튼**
- [ ] Empty/Loading/Error 상태 정리(→ UI_GUIDE) · 접근성/다크모드 검수
- [ ] CloudKit 동기화 실기기 검증 · CloudKit 스키마 Production Deploy

## Phase 2 — 결(depth) 더하기 (비경쟁 원칙 유지)
- [ ] **사진 CloudKit 동기화**(`ImageStore` → `CloudImageStore` 교체)
- [ ] **실제 Sign in with Apple** 연동(`AuthService` 실구현)
- [ ] 세션별 메모/인용구/하이라이트
- [ ] 장소 **키워드 검색(POI)** (Naver Developers 등록)
- [ ] BookSearch 제공자 재검토(Naver Books 등, 한국 메타데이터)

## Phase 3 — 확장 (출시 후)
- [ ] 위젯 · 활성 세션 **Live Activity**
- [ ] 잔잔한 회고(연말 되돌아보기 — 수치·경쟁 없이)
- [ ] iPad/Mac 최적화 · 내보내기(export) · Shortcuts
- [ ] 테마/표지 커스터마이즈

---
**항상 확인**: 새 항목이 "기억을 돕는가?"를 통과하는가. 목표·스트릭·경쟁·대시보드는 로드맵에 오르지 않는다.
