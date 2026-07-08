# DECISIONS — Passage

> 주요 의사결정 기록(ADR). 계속 추가된다. 형식: **결정 / 이유 / 트레이드오프·영향**.
> 결정을 뒤집을 땐 기존 항목을 지우지 말고 상태를 바꾸고 새 항목을 추가한다.

상태: ✅확정 · 🔵잠정(재검토 예정) · ⛔철회

---

### #1 — Memory over Productivity (제품 북극성) ✅
- **결정**: Passage는 독서를 *기억*으로 남기는 앱. 생산성/성취 도구가 아니다.
- **이유**: 기존 앱들의 목표·측정·경쟁이 독서를 과제로 만든다. 우리는 반대 지점을 점유한다.
- **영향**: Reading Goals · Streak · Gamification · 경쟁 · 랭킹 · Dashboard 중심 UI · 알림 압박을 **만들지 않는다.** 모든 기능은 "기억을 돕는가?"를 통과해야 한다.

### #2 — Session is Source of Truth ✅
- **결정**: `ReadingSession`이 앱의 원자 단위. 통계·저널 등 파생 데이터는 저장하지 않고 세션에서 계산한다. 활성 세션은 **시작 즉시 저장**하고 앱 재시작 시 복원한다.
- **이유**: 단일 진실 원천으로 정합성 유지, 파생값 동기화 버그 제거. 진행 중 세션이 크래시/종료로 사라지지 않게.
- **영향**: Book/Place는 참조 엔티티. Library 통계는 `FetchDescriptor` 집계. 성능이 문제되면 그때 캐시 도입.

### #3 — SwiftData 채택 ✅
- **결정**: 영속성은 SwiftData(Core Data 아님).
- **이유**: SwiftUI/Observation과 1급 통합, 보일러플레이트 최소, `@Query`로 선언적 조회. 솔로 유지보수에 유리.
- **트레이드오프**: 비교적 신생 → 일부 CloudKit 제약(§ARCHITECTURE 4). 복잡한 마이그레이션은 Core Data보다 도구가 적다 → `VersionedSchema`로 대비(#12).

### #4 — CloudKit private DB 동기화 ✅
- **결정**: 기기 간 동기화는 CloudKit private database(SwiftData 자동 미러링).
- **이유**: 서버·백엔드 유지보수 0, 사용자 프라이버시(본인 iCloud), 무료 한도. 솔로 개발자에게 최적.
- **트레이드오프**: Apple 생태계 한정. 스키마 제약(unique 불가, optional/기본값 필수). 대용량 사진은 별도 처리(#9).

### #5 — iOS 26+ / Swift 6 language mode ✅
- **결정**: 최소 타깃 iOS 26(현재 프로젝트 26.5), Swift 6 strict concurrency.
- **이유**: 최신 SwiftUI/SwiftData/Observation API 활용, 동시성 안전을 컴파일 타임에 확보. 신규 프로젝트라 레거시 부담 없음.
- **트레이드오프**: 구형 OS 미지원(제품 성격상 허용). 필요 시 26.0으로 하향 가능.

### #6 — Repository 패턴 미사용 ✅
- **결정**: 제네릭 `Repository<T>`를 만들지 않는다. 조회는 `@Query`/`FetchDescriptor`, 쓰기는 도메인 서비스 메서드로 캡슐화.
- **이유**: 제네릭 리포지토리는 SwiftData의 `ModelContext`/`@Query` 설계와 충돌하고 추상화 비용만 늘린다. 테스트 이점은 도메인 서비스로 충분히 확보.
- **트레이드오프**: 영속성 세부가 서비스에 노출 → 프로토콜 경계로 완화.

### #7 — MV 하이브리드(ViewModel 선택적) ✅
- **결정**: View마다 ViewModel을 강제하지 않는다. 비동기·다단계·지속 상태 흐름만 `@Observable` Store로. 단순 조회는 View+`@Query`.
- **이유**: SwiftUI+Observation은 불필요한 VM 없이도 견고. 과한 계층은 유지보수 부담.
- **트레이드오프**: "언제 Store를 만드나" 기준이 필요 → ARCHITECTURE §11에 명문화.

### #8 — Naver Maps(장소 기능) ✅
- **결정**: 지도/지오코딩은 Naver Maps. DronePass 패턴 재사용. 지도 뷰는 `UIViewRepresentable`로 SDK 래핑(**허용된 UIKit 예외**).
- **이유**: 국내 장소·주소 품질 우수, 검증된 연동 자산 보유. SDK가 UIKit 기반이라 브리지 불가피.
- **트레이드오프**: MVP는 지도 지점 선택 + reverse-geocode까지. **키워드 POI 검색은 별도 API(Naver Developers)** 필요 → Phase 2.

### #9 — 사진 저장: MVP 로컬 → Phase 2 SwiftData externalStorage ✅
- **MVP(Phase 1)**: 파일 기반 `LocalImageStore`(Application Support), SwiftData엔 참조 id만. 로컬 요구 충족.
- **Phase 2 전환(2026-07-04)**: 장소 사진을 **`PlacePhoto` @Model + `@Attribute(.externalStorage)`** 로 이동 → **SwiftData+CloudKit이 CKAsset으로 기기 간 자동 동기화.** 별도 `CloudImageStore`/수동 CKAsset보다 idiomatic·저유지보수. `StoredImageView` 제거, `PhotoThumbnail(data:)`로 표시.
- `ImageStore`/`LocalImageStore`는 향후 표지 로컬 캐시용으로 보존(현재 앱 미사용).
- **트레이드오프**: 실기기 2대 동기화 검증은 iCloud 계정+기기 필요.

### #10 — 시크릿 관리: gitignored Secrets.xcconfig ✅
- **결정**: 네이버 키 등은 `passage/App/Config/Secrets.xcconfig`(gitignore)에 두고 Info.plist `$()` 치환으로 주입. `.example` 템플릿 커밋. 소스 폴더 안이므로 xcconfig들을 **target membership 예외**(pbxproj)로 두어 앱 번들 유출을 막는다.
- **이유**: DronePass 검증 패턴. 코드/저장소에 시크릿 노출 방지.
- **영향**: 새 환경은 `.example` 복사 후 값 입력. 값 하드코딩 금지.

### #11 — Sign in with Apple: MVP 더미 → Phase 2 실연동 ✅
- **MVP(Phase 1)**: 더미 버튼(비활성).
- **Phase 2 전환(2026-07-04)**: `AuthStore`(@Observable @MainActor) — `SignInWithAppleButton` 완료 콜백에서 자격증명(user id·이름·이메일) 처리, UserDefaults 영속·복원, **재로그인 시 이름/이메일 보존**(Apple은 최초 로그인만 제공), `getCredentialState`로 취소 감지 로그아웃. `com.apple.developer.applesignin` entitlement 추가. `AuthService` 프로토콜/`DummyAuthService`는 제거(구체 @Observable 스토어로).
- **이유**: 데이터 정체성은 iCloud(CloudKit)에 묶이므로 로그인은 게이팅이 아니라 프로필/계정 표시용.
- **트레이드오프**: 기기 로그인은 'Sign in with Apple' capability 프로비저닝 필요. userID는 UserDefaults(비민감) — 강화 시 Keychain.

### #12 — VersionedSchema + MigrationPlan 1일차 도입 ✅
- **결정**: 처음부터 `SchemaV1` + `PassageMigrationPlan` 구성.
- **이유**: 수년 유지보수에서 모델은 반드시 변한다. 나중에 도입하면 초기 스키마 버저닝 소급이 어렵다.
- **영향**: 필드 변경은 새 `SchemaVn` + `MigrationStage`. 파괴적 변경 전 확인.

### #13 — BookSearch 제공자: Naver 책 검색 ✅
- **결정**: `BookSearchService` 프로토콜 뒤 **`NaverBookSearchService`**(기본). `GoogleBooksSearchService`는 대안으로 보존.
- **이유**: 무료 · **하루 25,000건**(Google 키 1,000의 25배) · 사업자등록 불필요(네이버 개인 계정) · **한국 도서 메타데이터·표지 최적**. (키 없는 Google Books는 공용 할당량 HTTP 429로 실사용 불가했음)
- **인증**: developers.naver.com '검색' 앱 등록 → Client ID/Secret. `NAVER_SEARCH_CLIENT_ID/SECRET`을 Secrets.xcconfig에 넣고 Info.plist `$()` 치환으로 주입(헤더 `X-Naver-Client-Id/Secret`). **지도용 Cloud Platform 키와 별개 시스템.**
- 파싱 테스트 3종(`<b>`태그·HTML 엔티티·ISBN13·공저 `^`)·검색 UI(`BookSearchView`)·표지(`BookCoverView`) 완료. 수동 등록("직접 입력")은 오프라인 경로.

---
### #14 — Swift 6 + Main Actor 기본 격리 ✅
- **결정**: Swift 6 language mode. 모듈 기본 액터 격리는 **MainActor**(Xcode 26 신규 템플릿 기본값 유지). UI·모델·대부분 서비스는 자동 MainActor, 오프메인이 필요한 IO 서비스만 명시적 `actor`(ImageStore·Auth).
- **이유**: SwiftUI/SwiftData와 마찰 최소, 크로스액터 브리지 회귀 위험 감소(작업 지침과 일치). 명시적 격리는 필요한 곳에만.
- **트레이드오프**: 네트워크/디코딩도 기본 MainActor(작은 페이로드라 무해). 커지면 그 지점만 `nonisolated`로 오프메인 전환. NaverMapService가 이 사유로 `@MainActor`.
- **@Model은 반드시 `nonisolated`**: SwiftData가 내부 스레드(특히 CloudKit 백그라운드 동기화)에서 모델에 접근하므로, MainActor 기본 격리를 받지 않도록 모든 `@Model`을 `nonisolated`로 표시한다. (미표시 시 오프메인 접근에서 런타임 트랩)

---
### #15 — 서재 UI 재구성: 보딩패스 비주얼 방향 (2026-07-08) 🔵
- **결정**: 서재 홈·세션 오버레이·책 추가를 Figma-Make 목업의 **보딩패스/티켓 메타포**로 재구성하고, **목업에 충실한 새 비주얼 방향**을 채택한다. 요소: 따뜻한 **책별 컬러 패스**(헤더 스트립·표지 스와치) · 티켓 절취선 · **바코드형 진행률** · **원형 시계 타이머**. 책별 색은 저장하지 않고 **`book.id` 기반 결정적 팔레트**(`PassagePalette`, FNV-1a 안정 해시)로 배정. 탭은 3개(서재·독서여정·세팅) 목표(회고는 삭제 없이 통합 — E단계).
- **이유**: "여정/티켓" 은유가 #1(Memory over Productivity)과 부합(목표·경쟁·수치 없음). 사용자가 다듬어진 목업을 명시적으로 채택. 비주얼 레이어가 사실상 그린필드(색/타이포/컴포넌트 토큰 부재)라 신규 토큰 추가로 구현.
- **트레이드오프·영향**:
  - **UI_GUIDE의 "뉴트럴+시스템색" 실행을 이 방향으로 갱신** — 독서 루프 표면(서재 홈·세션)은 `PassagePalette` 웜 토큰(라이트/다크 정의) 사용, 나머지(저널·회고·설정·상세)는 시스템 뉴트럴 유지. **하드코딩 색 금지 원칙은 유지**(색은 반드시 `PassagePalette` 토큰).
  - **고정 메트릭 예외**: dense한 티켓/타이머 레이아웃은 목업 비례 유지를 위해 고정 pt 사용(Dynamic Type 대신). VoiceOver 라벨·다크모드·Reduce Motion은 유지.
  - **폰트**: 목업 Archivo는 한글 미지원 → 한국어 시스템 폰트, 숫자는 `monospacedDigit`. Archivo 미채택.
  - **진행률**은 세션에서 신규 파생(`maxEndPage/totalPageCount`; 네이버 검색 `pageCount=nil`이면 폴백 라인). #2 파생 원칙 유지.
  - **장소 플로우 무회귀**: 세션 종료 후 장소는 기존 `WhereDidYouReadView`(지도·POI·사진) 유지. 목업의 **인라인 장소+장식 미니맵은 보류**.
  - 세션 생명주기에 **준비(ready)·일시정지** 단계 추가(`ReadingSessionController` 상태머신 가산). **책 삭제** 신규(cascade).
- **상태**: ✅확정 — 홈(패스 스택)·세션 오버레이·책 추가 시트·화면 모드·삭제 확인 모달·3탭 재구성·**세션 종료 인라인 장소(장식 미니맵·GPS 자동채움)**·문서 정합 완료(커밋 57668d4·c065551·9e0cde8·fa91a8e·52c70c0·dc6b3f3).
- **장소 반영 방식**: ended 인라인 저장(`finishEndedInline` — 이름을 `Place`로 생성·연결하고 바로 종료)과 미니맵 탭→기존 `WhereDidYouReadView`(최근 장소·지도 탭·POI·사진) 리치 플로우, 두 경로 공존(**무회귀**).
- 참고: 3탭 라벨은 '서재·독서여정·설정'(목업의 '세팅' 대신 기존 표준어 '설정' 유지). 회고는 독서여정 툴바→시트.

### #16 — 화면 모드(시스템/라이트/다크) ✅
- **결정**: 설정에 화면 모드 선택 추가. **기본은 시스템(폰 설정을 따름)**, 라이트/다크 선택 시 앱 전역 override. `AppearanceMode`(system→`colorScheme` nil) + `RootView`의 `preferredColorScheme`(윈도우 전역·세션 오버레이 포함) + `@AppStorage("appearanceMode")`.
- **이유**: 사용자 요청. 재구성으로 커스텀 팔레트가 라이트/다크 둘 다 정의되어 강제 전환이 자연스럽다.
- **트레이드오프**: 시스템 자동(다크모드 검수, UI_GUIDE)을 기본으로 유지 — override는 사용자가 명시적으로 고를 때만.

---
*새 결정은 아래에 #17부터 이어서 기록한다.*
