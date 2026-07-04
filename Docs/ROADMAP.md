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
- [x] **Xcode UI**: xcconfig(`passage/App/Config/`)를 Debug/Release 구성에 지정 · SPM(NMapsMap 3.21.0) · CloudKit capability — 완료. (xcconfig는 소스 폴더 안이라 target membership 예외로 번들 제외 → 시크릿 유출 방지)

## Phase 1 — MVP 핵심
순서는 데이터 흐름을 따른다: **책 → 세션 → 장소 → 회상**.

### 1a. Book
- [x] 수동 등록(제목/저자/ISBN/페이지) · 책 상세(세션 파생 통계) · Library 목록/카드 — 빌드·데이터 테스트·실행 검증 완료
- [x] 검색 등록(`BookSearchView` + Google Books) · ISBN 조회 · 표지(`BookCoverView`) — 파싱 테스트 3종·빌드 그린. **활성화: `GOOGLE_BOOKS_API_KEY` 필요**(키 없으면 공용 할당량 429). 제공자 교체 가능(DECISIONS #13)
- [ ] 책 삭제/편집

### 1b. Reading Session (Source of Truth)
- [x] `ReadingSessionController`: Start/Stop/Cancel · 활성 세션 즉시 저장 · **앱 재시작 시 복원** — 로직 테스트 4종 통과
- [x] 읽는 중 화면(TimelineView 경과 시간) · 전역 fullScreenCover로 표시
- [x] 종료 페이지(선택) 입력 — 시작 페이지 입력 UI는 후속
- [ ] 장소 질문 연결은 1c에서

### 1c. Place — "어디서 읽으셨나요?"
- [x] 종료 직후 장소 프롬프트: 기존 선택 / 새로 생성 / 건너뛰기 (전역 fullScreenCover 콘텐츠 전환)
- [x] `NaverMapView`(UIViewRepresentable · NMapsMap) 탭 지점 선택 · `LocationService` 현재 위치
- [x] `NaverMapService` reverse-geocode로 주소 자동 채움
- [x] 사진 첨부(`LocalImageStore`, 로컬 저장) · 장소 이름 지정
- [x] → 세션에 book·place 연결하여 **기억 저장 완료** — 로직 테스트 3종 통과, 앱 실행 검증
- [ ] (남음) 대화형 지도 탭 플로우는 Xcode 실사용 확인 권장(라이브 키+네트워크). reverse-geocode DTO는 실응답으로 보정 필요.

### 1d. Library & Journal (회상)
- [x] Library: 책 카드에 총 독서시간·세션 수 표시(읽은 장소는 책 상세에서) — 세션 파생
- [x] Journal **책 렌즈** · **장소 렌즈**(세그먼트) 그룹 타임라인 — 그룹핑 로직 테스트 2종, 실행 렌더 검증
- [x] Memory 상세(책·장소·시간·페이지·사진) · `StoredImageView`로 로컬 사진 로드

### 1e. 마감
- [x] Settings + Sign in with Apple 더미 버튼 (레이아웃 375pt 캡·접근성 라벨) — 실제 연동은 Phase 2(applesignin capability 필요)
- [x] Loading(지오코딩·현재위치) 상태 · Empty 상태 · 접근성(VoiceOver 라벨) · **다크모드 검수(실행 스크린샷 확인)**
- [ ] CloudKit 동기화 실기기 검증 · Production Deploy — iOS 27 베타 기기 이슈로 보류(iOS 26.5/정식판에서 진행)

## Phase 2 — 결(depth) 더하기 (비경쟁 원칙 유지)
- [ ] **사진 CloudKit 동기화**(`ImageStore` → `CloudImageStore` 교체)
- [ ] **실제 Sign in with Apple** 연동(`AuthService` 실구현)
- [x] 세션 회고 메모(`NoteEditorView`) + **인용구/하이라이트**(`Quote` 모델 · `AddQuoteView` · BookDetail 섹션, 스키마에 Quote 추가)
- [ ] 장소 **키워드 검색(POI)** (Naver Developers 등록)
- [x] BookSearch 제공자 → Naver 책 검색 확정·구현 (#13)

## Phase 3 — 확장 (출시 후)
- [ ] 위젯 · 활성 세션 **Live Activity**
- [ ] 잔잔한 회고(연말 되돌아보기 — 수치·경쟁 없이)
- [ ] iPad/Mac 최적화 · 내보내기(export) · Shortcuts
- [ ] 테마/표지 커스터마이즈

---
**항상 확인**: 새 항목이 "기억을 돕는가?"를 통과하는가. 목표·스트릭·경쟁·대시보드는 로드맵에 오르지 않는다.
