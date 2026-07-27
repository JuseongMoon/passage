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

### #5 — iOS 배포 타깃 / Swift 6 language mode ✅ (배포 타깃은 아래 정정 참조)
- **결정**: 최소 타깃 iOS 26(현재 프로젝트 26.5), Swift 6 strict concurrency.
- **이유**: 최신 SwiftUI/SwiftData/Observation API 활용, 동시성 안전을 컴파일 타임에 확보. 신규 프로젝트라 레거시 부담 없음.
- **트레이드오프**: 구형 OS 미지원(제품 성격상 허용). 필요 시 26.0으로 하향 가능.
- **정정(2026-07-26, 사용자 확인)**: 실제 **앱 타깃의 `IPHONEOS_DEPLOYMENT_TARGET`은 18.6**이고 **이 설정이 맞다.** 프로젝트 레벨·테스트 타깃 값 26.5는 앱 타깃이 덮어쓰므로 착각하기 쉽다. 문서만 "iOS 26+"로 어긋나 있었고 `Docs/CLAUDE.md`·`Docs/UI_GUIDE.md`를 정정했다. → **iOS 26 전용 API는 사용 불가**(사례: #24의 `Slider(neutralValue:enabledBounds:)` → 커스텀 구현으로 전환). 최신 API 도입 전 가용 버전을 반드시 확인한다.

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
### #17 — 도서 페이지 수 보조 조회: 알라딘 1순위 + Google Books 폴백 ✅
- **결정**: 네이버 책 검색이 `pageCount`를 주지 않으므로(#13), 책 추가 시 ISBN으로 페이지 수를 **보조 조회**해 `Book.totalPageCount`를 채운다(→ 진행률 바코드 자동 표시). `PageCountService` 프로토콜 뒤 **알라딘 ItemLookUp `subInfo.itemPage`(1순위)** → **Google Books `volumeInfo.pageCount`(폴백)**. `PageCountFiller`(@MainActor)가 추가 후 백그라운드로 채운다(사용자가 그새 수동 입력했으면 덮지 않음).
- **이유**: 진행률 바코드는 `totalPageCount`가 필요. 조사 결과 **알라딘**이 국내서 커버리지·깔끔한 정수 필드로 최적(무료 TTBKey). 카카오/네이버는 페이지 수 미제공, **국립중앙도서관 Seoji(`PAGE`)**는 문자열 파싱 + 키 승인이 필요해 후순위(추후 추가 가능).
- **트레이드오프**: 알라딘 TTBKey는 `Secrets.xcconfig`(선택). 없으면 Google Books 폴백(무키 공용 할당량, 국내서 편차)/수동 입력으로 **우아하게 degrade**. 알라딘 `output=js` JSON이 드물게 비표준이면 파싱 실패→폴백. https 사용(ATS 예외 불필요 추정, 실패 시 http+예외 검토).
- **상태**: ✅ (실호출 검증은 TTBKey 입력 후 환경에서).

---
### #18 — 톤 통일: 웜 팔레트를 저널·설정까지 확장 ✅
- **결정**: #15에서 **독서 루프(서재·세션·책 추가)만** 웜 `PassagePalette`로 가고 저널·회고·설정은 시스템 뉴트럴로 두기로 했으나, **전 탭의 톤을 서재 기준으로 통일**한다. 다만 *메타포 복제*가 아니라 ***톤의 토대*(웜 `appBg` 배경 · 커스텀 대형 잉크 헤더 · `ink/inkMuted` 텍스트 · `cardBody` 카드 · `warmAccent`)만 이식**하고, 티켓/바코드 모티프는 독서 루프에 한정한다(설정에 강요 금지 — Calm·Minimal).
- **이유**: 1탭만 브랜디드고 2·3탭이 맨 iOS라 "반쯤 완성" 인상. 톤 통일이 완성도를 높인다. 사용자가 "톤 통일(권장)" 강도를 명시 선택.
- **트레이드오프·영향**:
  - **#15의 "나머지는 시스템 뉴트럴" 실행을 이 방향으로 갱신.** 철학(Calm·Reflective, Memory over Productivity)·하드코딩 색 금지·색은 `PassagePalette` 토큰만 원칙은 유지.
  - **공용 컴포넌트 승격**: 서재 인라인 헤더 → `Core/DesignSystem/PassageScreenHeader`(워드마크·타이틀·서브타이틀·트레일링 액션). 서재·저널·설정이 공유(UI_GUIDE §7).
  - **저널**: 시스템 라지타이틀·`List` 기본 → 커스텀 헤더("독서여정" + "N개의 기억" + "회고" 웜 알약) · 웜 세그먼트 렌즈(잉크 알약) · `cardBody` 카드 로우(`.scrollContentBackground(.hidden)`). `ReflectionView` 잉크색 정렬.
  - **셀 대칭(`MemoryRow`)**: 두 렌즈가 모양이 달라 보이던 문제 해결 — 둘 다 **[강조 타이틀 + 메타(날짜·시간)]** 대칭 구조로. 책 렌즈는 각 행의 주인공이 "장소"(`warmAccent` 핀), 장소 렌즈는 "책 제목"(serif). 장소 미기록 시 "장소 기록 없음" 폴백.
  - **기억 상세(`MemoryDetailView`)**: 시스템 `List` → 웜 톤 — **표지 히어로**(`BookCoverView` + serif 제목 + 저자) + `cardBody` 카드 섹션(기록·생각·장소) · `warmAccent`(편집·장소 핀). push 상세라 nav 바(뒤로)는 유지.
  - **전체 여정보기(`BookDetailView`)**: 서재 메뉴 "전체 여정보기"가 '기획상 애매'(이름과 달리 개별 기록이 안 보이고 "읽기 시작"만 있던 문제)해 재편 — **"읽기 시작" 버튼 제거**(서재 패스 CTA와 중복), 히어로 아래 **요약 한 줄**(`N개의 여정 · 총 시간`) + 그 책의 **전체 세션 기록 최신순 목록**(`MemoryRow`(showsBook:false) 재사용, 탭→`MemoryDetailView`) + 인용구. 통계 섹션·ISBN 정리, 웜 톤. 독서여정 탭과 같은 셀·상세 흐름으로 일관.
  - **설정**: 웜 배경 + 커스텀 헤더 + `cardBody` 카드 섹션. Sign in with Apple·화면 모드 세그먼트 유지(로그아웃 = `PassagePalette.danger`).
  - **접근성 유지**: `.isHeader`·`.isSelected` 트레이트, Reduce Motion 존중(세그먼트 애니), 라이트/다크 양쪽 검수(프리뷰 렌더 확인).
- **상태**: ✅확정 — 빌드 성공, 저널·설정 라이트/다크 프리뷰 검증, 서재 무회귀 확인.

---
### #19 — 페이지 표시를 "도달 위치"로 일관화 + 다권 세트는 누적 페이지 전제(볼륨 미지원) ✅
- **결정**: 페이지는 앱 전체에서 **도달한 절대 위치(endPage)** 기준으로 통일한다.
  - 서재 패스 카드의 최근 여정기록 메타: **페이지 델타(그 세션에서 읽은 쪽수)** → **도달 페이지(endPage)** 표시(`PassPresentation.journeyMeta`).
  - 이어읽기 시작 페이지 제안(`ReadingSessionController.suggestedStartPage`): **모든 세션의 max** → **가장 최근에 끝낸 세션의 도달 페이지**. 주석 의도("지난 세션의 마지막 페이지")와 일치.
  - 첫 독서(지난 세션 없음)는 1페이지부터 기록(#18 후속, `confirmStart`).
- **이유**: 카드는 델타(예: "80p")를, 시작 제안은 절대 위치(예: 280)를 보여줘 **같은 화면에서 서로 다른 의미의 페이지가 충돌**해 혼란(사용자 리포트). 진행률·시작 제안이 이미 절대 위치라, 카드도 절대 위치로 맞추는 게 일관적이고 "Memory over Productivity"(수치보다 "어디까지 왔나")에 부합.
- **다권 세트 한계(볼륨 미지원)**: `Book`은 **권 개념 없이 단일 연속 페이지 스케일** 하나만 가진다.
  - **누적 페이지로 입력**하면(1권 끝 다음 권을 이어서) 카드·진행률·시작 제안이 모두 정상.
  - **권마다 페이지를 리셋**해 입력하면 한 축에서 숫자가 역행(예: 280→80)해, 카드의 "→" 진행이 어색하거나 진행률%가 부정확할 수 있다. 단 **이어읽기 페이지 제안은 "가장 최근" 기준이라 올바르게 동작**(오히려 이번 변경으로 개선).
  - **결정**: 볼륨/섹션 개념은 **추가하지 않는다**(모델 복잡화 · Calm·Minimal에 반함). 다권 세트는 **누적 페이지 입력을 전제**로 하고, 리셋 입력 시의 진행률/시각적 어색함은 수용한다.
- **상태**: ✅ 빌드·테스트 통과(`PassPresentationTests`·`ReadingSessionControllerTests`), 카드 렌더로 도달 페이지 진행 확인.

---
### #20 — 독서여정 탭 지도 중심 재설계 + 책 완독 상태 도입 ✅
- **결정**: 2번 탭 `JournalView`를 **리스트 타임라인 → 지도 중심 화면**으로 전면 재설계(프로토타입 `Passage Journey.html` 기준). "무엇을·어디서·얼마나 읽었나"를 **공간(지도)으로 회상**한다 — Memory over Productivity에 부합(지도는 압박이 아닌 회상 도구).
  - **구성**: 헤더 요약 한 줄(`N시간 동안 M권의 책을 K곳에서 읽었어요`, 전체 누적) + **Naver 지도 히어로**(책 표지를 읽은 장소에 마커로) + `전체/진행 중/완료` 필터 캡슐 + 가로 카드 캐러셀(표지·총시간·`N곳의 여정`).
  - **인터랙션**: 카드/마커 탭 → 그 책 **포커스**(지도가 그 책의 장소들로 이동, **점선 경로(polyline)**로 방문 순서 연결, 각 장소에 `이름 · 체류시간` 캡션, 선택 카드 강조·나머지 흐림, `전체 여정보기` 버튼 → 개요 복귀). 필터는 지도 마커+카드를 동시에 거른다.
- **완독 상태(진행 중/완료)**: `Book`에 `finishedDate: Date?` 신설(옵셔널→CloudKit 안전, 파괴적 아님) + **SchemaV2 + `.lightweight` 마이그레이션**(#12 관용대로). `진행 중`=nil / `완료`=값 있음. `BookDetailView`에 "다 읽음/읽는 중" 토글. (필터의 근간 — 기존엔 완료 개념 자체가 없었음.)
- **좌표 정책(사용자 결정)**: 신규 장소 입력 시 **좌표 필수화**(`NewPlaceView` 지점 미선택 시 저장 불가). 기존 좌표 없는 장소는 지도 렌더 시 **현재 위치로 fallback**(권한 있을 때 조용히 취득, 없으면 그 장소만 생략 — 프롬프트 강요 안 함). 독서기록에서 **독서 위치 변경**(`ChangePlaceView`: 기존 장소 재사용/새 장소 → `assignPlace`, `MemoryDetailView` "위치 변경/추가"). ended 인라인 quick-place는 GPS 자동채움+fallback로 커버(calm 유지 위해 강제 안 함).
- **회고**: 지도 중심 단순화를 위해 **독서여정 탭의 회고 진입점 제거**(#18에서 통합했던 툴바 "회고" 버튼/시트 삭제). `ReflectionView`/`ReflectionOrganizer` **코드는 존치**(재도입 여지).
- **집계·렌더 구조**: 책별 파생값은 **Journal 로컬 순수 타입 `BookJourney`/`JourneyStop`/`JourneySummary`**(Core 모델에서만 파생, Feature 격리상 Library의 `PassPresentation` 미import)로 신설 — 완료 세션을 장소별로 첫 방문 순 그룹핑(중복 제거 `Set<UUID>`, `ReflectionOrganizer` 패턴 응용). 지도는 **전용 `JourneyMapView`**(다중 마커·`NMFPolylineOverlay`+`.pattern` 점선·`NMFOverlayImage` 표지 마커·`NMGLatLngBounds` fit) — 장소 피커용 단일 지점 `NaverMapView`는 **건드리지 않음**(무회귀). 표지→마커 UIImage는 `BookCoverMarker`(다운로드·swatch 폴백·캐시). SDK 콜백은 기존 관용구(Sendable 값만, `Task{@MainActor}`), 색은 traitCollection으로 미리 해석한 정적 UIColor(off-main dynamicProvider 회피, #14).
- **트레이드오프·주의**:
  - `NMFCameraUpdate(fit:padding:)`의 padding이 실기에서 무시되어 극단 마커가 가장자리에 걸림 → **bounds를 직접 35% 확장**해 여백 확보. fit은 레이아웃 이후(뷰 크기>0) 실행되도록 async로 미룸(첫 `updateUIView`는 크기 0).
  - 좌표 fallback은 무좌표 legacy 장소를 현재 위치에 몰리게 함(의도된 브리지 — 신규 필수화로 점진 해소).
  - 개발 중 레거시 SwiftData 스토어(스키마 이력 불일치)는 V1→V2 마이그레이션에서 abort → **개발 스토어 초기화 필요**(앱 미출시라 실 사용자 마이그레이션은 무해).
- **상태**: ✅ 빌드·전체 테스트(59, `BookJourneyTests` 신규) 통과, 시뮬레이터 E2E(지도 타일·표지 마커·개요/포커스·점선 경로·캡션·캐러셀 강조/필터) 스크린샷 검증, 프로덕션 런치·서재 무회귀 확인.

---
### #21 — 서재 카드색을 표지 대표색에서 추출 + 진행률 표시 간소화 ✅
- **결정**: 서재 보딩패스 카드의 헤더 색을 **book.id 해시 프리셋 → 책 표지의 대표색**에서 뽑는다(개선판 프로토타입 `기획문서/Passage Home v2.html` 기준). 색 가공은 **은은한 톤**(채도·명도를 중간 밴드로 정규화), 헤더 텍스트는 **명도 기반**(밝으면 어두운 잉크 `#26241F`, 아주 어두우면 흰색 자동)으로 프로토타입의 "은은한 헤더 + 다크 텍스트"를 재현.
- **범위 = 서재 카드만(사용자 결정)**: 중앙 `PassagePalette.swatch(for:)`는 **불변** → 표지색 분기는 `PassPresentation`에만. `BookJourney`(독서여정 카드·지도 마커)·`ReadingSessionView`(독서 중 화면)는 기존 해시 팔레트 유지.
- **진행률 표시(사용자 지시)**: 바코드(`BarcodeProgressView`) **제거**, 진행률 %는 **총 독서시간 옆에 숫자만**(`2시간 45분 48%`). 전체 페이지 수 모를 때의 "전체 페이지 수 입력" 프롬프트는 유지(% 가 없을 때만 노출). `BarcodeProgressView.swift` 삭제.
- **구현**:
  - `Book.coverColorHex: String?`("RRGGBB") 신설 + **SchemaV3 lightweight 마이그레이션**(#12·finishedDate와 동일 패턴).
  - `CoverColorFiller`(`Features/Book/`, `PageCountFiller` 미러) — 서재 진입 `.task`에서 `backfillMissing()`(표지 있고 색 없는 책만, 멱등). 추출 `extractHex`는 **off-main**(`URLSession` 다운로드 → `CIFilter.areaAverage()` 1×1 렌더 → RGBA), 모델 쓰기만 MainActor. 신규 책도 이 백필로 커버(AddBook/Search 무변경).
  - `PassagePalette.coverSwatch(hex:)` + `PassageColorMath`(RGB↔HSB·상대휘도) — 전부 **고정 hex Color**(라이트/다크 동일, 동적 프로바이더 미사용 → off-main 트랩 #14 없음). base=은은한 정규화(S≤0.52, B∈[0.60,0.74]), ink=휘도<0.16이면 흰색.
  - 표지 없음/추출 실패 → 기존 해시 팔레트 폴백(무회귀).
- **트레이드오프·주의**:
  - **평균색(CIAreaAverage)** 은 은은한 결과를 잘 주지만 복잡한 표지는 회색에 가까울 수 있음(정규화로 완화, 필요 시 최빈색 방식 여지). 실기 검증: The Waves→세이지, Piranesi→테라코타, Field Guide→그레이로 표지와 어울리는 은은한 톤 확인.
  - **비동기 지연**: 첫 진입 시 폴백색 → 추출 후 갱신(progressive). 다크 모드는 헤더 고정색+다크 잉크 유지(가독), 바디는 적응.
  - **폴백 톤 혼재**: 표지 있는 책(은은+다크잉크)과 없는 책(프리셋 선명+흰잉크) 혼재 — 대부분 표지 있어 수용.
  - **⚠️ 마이그레이션**: CloudKit 백엔드 스토어의 lightweight 마이그레이션이 기존 개발 스토어에서 abort(V2→V3, #20의 V1→V2와 동일 증상) → **개발 스토어 초기화 필요**(앱 미출시라 무해). **실 사용자 마이그레이션 정확성은 미검증 — 스키마 변경 배포 전 재검토 필요**(반복 이슈).
- **상태**: ✅ 빌드·전체 65 테스트(신규 6: coverSwatch·폴백·명도 잉크·색 math) 그린, 실제 표지 URL로 시뮬레이터 E2E(표지색 카드·% 표시·바코드 제거·라이트/다크·해시 폴백) 스크린샷 검증. 플랜 `~/.claude/plans/2-sparkling-puffin.md`.

---
### #22 — VersionedSchema+MigrationPlan 제거, 자동 lightweight 마이그레이션으로 전환 ✅ (#12 대체)
- **문제**: `#20`(SchemaV2)·`#21`(SchemaV3)에서 버전 스키마를 추가했으나, **`SchemaV1/V2/V3`가 모두 같은 현재 `Book` 클래스**(모든 필드 포함)를 가리켜 세 버전의 **체크섬이 동일** → 기존 스토어가 있는 기기/시뮬레이터에서 `ModelContainer(for:migrationPlan:)` 생성 시 **`NSInvalidArgumentException: 'Duplicate version checksums detected.'` 런치 크래시**(사용자 리포트, iPhone 17 Pro Max). 개발 중 fresh 스토어(초기화)에선 우회돼 안 보였을 뿐, 근본은 코드 버그.
- **근본 원인**: SwiftData `VersionedSchema`는 **버전마다 모델 스냅샷**(그 시점의 필드로 고정된 별도 타입)을 가져야 체크섬이 달라진다. 하나의 진화하는 `Book`을 여러 버전이 공유하면 전부 동일 체크섬. `#12`가 "1일차 VersionedSchema+MigrationPlan"을 정했지만 스냅샷 없이 도입해 실질적으로 미작동(마이그레이션 abort·중복 체크섬).
- **결정**: 앱은 **미출시**(마이그레이션할 실 버전 없음)이고 지금까지 변경이 전부 **additive(옵셔널 필드 추가)** 이므로, **`VersionedSchema`+`MigrationPlan`을 제거**하고 **단일 `Schema([Book, ReadingSession, Place, Quote, PlacePhoto])` + `migrationPlan` 미지정(SwiftData 자동 lightweight 마이그레이션)** 으로 전환. `SchemaV1/V2/V3.swift`·`PassageMigrationPlan.swift` 삭제. 자동 마이그레이션이 기존 스토어에 옵셔널 컬럼을 안전하게 추가.
- **향후**: **비-additive/파괴적 변경**(필드 삭제·타입 변경·관계 재구성)이나 **출시 후 버전 간 마이그레이션**이 필요해지면, 그때 **버전별 모델 스냅샷을 제대로 갖춘 `VersionedSchema`+`MigrationStage`(custom 포함)** 를 도입한다(#12의 의도를 올바른 형태로). 파괴적 변경 전 사용자 확인 원칙 유지.
- **상태**: ✅ 빌드·전체 65 테스트 그린. **사용자 시뮬레이터(iPhone 17 Pro Max, 기존 실데이터 스토어 유지)에서 크래시 없이 실행·자동 마이그레이션·표지색 렌더 확인**(1Q84→그레이라벤더, 소년이온다→앰버, 헤일메리→퍼플). fresh 설치도 정상.

---
### #23 — 프로토타입 v2 반영(독서여정 통합·서재 필터·가로 갤러리·감상 메모) ✅
- **배경**: 최신 기획이 Claude 아티팩트 "Bundled Page" HTML(인터랙티브 Vue 프로토타입)로 전달됨. 앞으로도 동일 형식. 디코딩·분석 절차를 `scripts/decode-prototype.py`로 자동화 — 리소스맵(gzip+base64)에서 라이브러리/로더 JS·폰트 분리, 렌더링 HTML·화면 텍스트 추출, 로컬 http 서버 안내. **전체 화면·네비게이션은 로컬 서버로 브라우저 확인**(file:// 차단, 정적 HTML엔 초기 화면만 — 나머지는 클릭 전환).
- **결정(사용자 확정)**: 책 상세를 독서여정 탭에 **완전 통합**, 독서여정 전체 목록을 **가로 표지 갤러리**로.
- **구현**:
  - 독서여정 통합: `AppRouter`(탭 선택+포커스 요청) 신설, `RootView` `TabView(selection:)`. 서재 "여정보기"→`router.openJourney`→독서여정 탭 + 책 포커스. 포커스 시트 = `BookJourneyDetailSheet`(히어로·완독 토글·여정 기록[세션별→`MemoryDetailView`]·인용구) — 구 `BookDetailView` 흡수. 포커스 진입 detent=`.collapsed`로 지도 여정 경로 노출.
  - 서재: 헤더 `LibraryFilter` Menu(모든 책/읽는 중/완독, `filteredBooks` 기준), `PassCardView` CTA `[여정보기][책 읽기]` 2버튼. "+ 책 추가" 알약은 `PassStackView` 레이아웃 회귀 위험으로 현행 유지.
  - 색 통일: `BookJourney.swatch`·`BookCoverMarker` 폴백을 서재와 동일(coverColorHex 우선, `swatch.base`) — 같은 책이 서재·지도·갤러리에서 같은 색.
  - 데드코드 제거: `BookDetailView`·`CircularTimerView`·`ReflectionView`. `ReflectionOrganizer`·`MemoryOrganizer`는 테스트 커버라 유지(사용자 결정).
- **기획 보완(A-1)**: 프로토타입 세션 저장엔 감상이 없어 Memory over Productivity와 어긋남 → 세션 종료(ended) 화면에 "생각" 메모(`session.note`) 입력 추가. `finishEnded`·`finishEndedInline`에 note 파라미터. 기존 `MemoryDetailView` "생각" 섹션에서 조회/편집.
- **미반영(향후 후보)**: 필터 결과 0건 빈 상태 안내, 장소 없는 세션의 여정 표현. (세팅 화면은 프로토타입 미구현이나 현행 앱에 이미 존재.)
- **상태**: ✅ 빌드·전체 유닛 테스트 통과, iOS 26.5 시뮬 E2E(서재 필터·CTA·독서여정 가로 갤러리·책 포커스 지도 경로·감상 메모) 스크린샷 검증. `JourneyMapView`·`project.pbxproj`(버전만) 등 세션 무관 변경은 커밋 제외.

---
### #24 — 페이지 입력을 슬라이더로 전면 교체 + 상한 규칙 단일화·기존 데이터 강제 교정 ✅
- **문제**: 세션 페이지 입력에 검증이 전혀 없어 **전체 500쪽 책에 999쪽 저장이 가능**했다(`Int(텍스트)`만 통과). 진행률은 `PassPresentation`이 `min(1,…)`로 clamp해 표시상 문제가 없었지만, 오염된 값이 그대로 남아 **다음 세션 시작 페이지 제안(`suggestedStartPage`)·여정 기록 문구("999p")** 로 번졌다. 게다가 저장된 페이지를 고칠 UI가 없어(기억 상세는 메모·장소만 편집) **책 전체 삭제 말고는 복구 수단이 없었다.**
- **결정(사용자 지시)**: 앱이 미출시이므로 **파괴적으로 강제 교정**한다. 되묻는 확인 모달·양자택일 UX는 채택하지 않는다.
  - **`totalPageCount`가 상한의 유일한 권위** — 세션 페이지·인용구 페이지는 언제나 그에 종속된다. 상한을 넘으려면 상한을 먼저 고쳐야 한다(단방향).
  - **페이지 입력 경로를 슬라이더 하나로 단일화**: 숫자 키패드로 세션 페이지를 넣던 두 필드(시작/끝)를 없앴다. **ready(읽기 시작 전 시작 페이지)도 통일** — 앱을 쓰기 전부터 읽던 책이면 지금 위치로 옮겨야 하므로 하한 없이 전 범위를 움직인다. ended는 `lowerLimit = 시작 페이지`라 **역전(시작 > 끝)이 구조적으로 불가능**하다.
- **`Slider`(iOS 26 `neutralValue`/`enabledBounds`) 대신 커스텀 구현(사용자 결정)**: 앱 타깃 배포 버전이 **iOS 18.6**(프로젝트 레벨 26.5를 앱 타깃이 덮어씀)이라 해당 API를 쓸 수 없다. 당시 문서는 "iOS 26+"로 잘못 적혀 있었고, **설정이 맞다는 사용자 확인에 따라 문서를 정정**했다(→ #5 정정). 배포 타깃을 올리는 대신 커스텀 `PageSlider`를 만들어 **보딩패스 톤(책 색 swatch)에 맞춘 3구간 트랙**(이전에 읽은 곳 / 이번에 읽은 곳 / 남은 곳)을 직접 그린다. 트랙 전체는 **언제나 책 전체(1…total)** 라 내 위치가 책의 어디쯤인지 읽힌다.
- **정밀도 보완(사용자 요청)**: 300쪽 책에서 트랙 1pt ≈ 1페이지라 손가락으로 정확히 짚을 수 없다 → **큰 숫자를 누르면 숫자 직접 입력(alert + numberPad) → 확인 시 슬라이더와 값이 동기화**된다. 접근성(손 조작이 어려운 경우)의 대체 경로이기도 하며, VoiceOver는 `accessibilityAdjustableAction`으로 지원한다.
- **구현**:
  - `PageRules`(`Core/Models/`) — 순수 규칙. nil은 미기록 유지 · 0 이하는 nil · 상한 초과는 clamp · 역전은 swap(레거시 교정용, 슬라이더 경로에선 발생 불가).
  - `ReadingSession.normalizePages(in:)` — 저장된 값 **강제 교정**(세션 + 인용구 + 0/음수 total). `Book.normalizeTitles`와 같은 자리(`LibraryView.task`)에서 멱등 실행 → CloudKit으로 들어오는 타 기기 데이터도 커버. **슬라이더보다 반드시 먼저 돌아야 한다** — `999…500` 같은 역전 범위가 남아 있으면 트랙을 그릴 수 없다. `normalizePages(of:)`는 상한이 바뀐 직후(전체 페이지 수 입력·자동 조회) 그 책만 맞춘다.
  - 저장 계층 이중 방어: `finishEndedInline`·`confirmStart`가 UI 값과 무관하게 규칙을 통과시키고, `suggestedStartPage`도 clamp.
  - 상한 무결성: `AddBookView`가 0을 저장하던 문제 수정, `LibraryView.savePageCount`·`PageCountFiller`는 상한 변경 후 그 책을 재정규화(**상한을 낮추면 기존 기록도 따라 내려온다** — 방금 입력한 값이 더 정확하다고 본다).
- **용어 · 라벨(사용자 지시)**: 슬라이더의 큰 숫자만으로는 무엇인지 알 수 없어 **왼쪽에 라벨**을 붙였다(`시작 페이지` / `도착 페이지`). 종료 페이지의 "종료"는 **책의 마지막**으로 읽혀 오해를 부르므로, 보딩패스·독서여정 컨셉과 맞는 **"도착 페이지"**(시작↔도착 대칭)를 택했다. 라벨은 접근성 문구·직접 입력 알림 제목에도 함께 쓰인다.
- **표기**: 페이지는 수량이 아니라 **번호**이므로 로케일 천 단위 쉼표를 넣지 않는다(`Text(verbatim:)` — 그냥 `Text("\(Int)")`로 쓰면 "1,428p"가 된다).
- **트레이드오프**:
  - **전체 페이지 수를 모르면 슬라이더를 그릴 수 없다** → 세션 화면에서 전체 페이지 수를 한 줄로 입력받고(채우면 즉시 슬라이더로 전환), 건너뛰면 그 기록은 **페이지 없이** 저장된다. 세션 페이지의 숫자 폴백은 두지 않아 입력 경로를 하나로 유지했다.
  - **ScrollView 안 슬라이더의 제스처 충돌**: 트랙은 `minimumDistance: 0`이라 탭-투-점프가 되는 대신 트랙 위(높이 44)에서 세로 스크롤이 막힐 수 있다(시스템 슬라이더와 동일 거동). **실기 확인 권장.**
  - 드래그 중에는 `@State` Int만 갱신하고 SwiftData 쓰기는 저장 시 1회 — 스크럽 중 영속화 부하 없음.
- **상태**: ✅ 빌드 그린 · **전체 79 테스트 통과(신규 `PageRulesTests` 14: 상한·역전·0·멱등·상한 하향·진행률 정합)** · `PageSlider` 프리뷰 렌더 검증(3구간 트랙·시작 지점 마커·1p/총쪽 눈금) · 시뮬레이터(iOS 26.5) 실행에서 정규화 패스 포함 서재 정상 렌더·크래시 없음. **ready/ended 화면의 슬라이더 통합 배치는 실기 확인 필요** — `ReadingSessionView`의 Xcode 프리뷰가 `__designTimeSelection` 모호성(프리뷰 인스트루멘테이션 이슈, 앱 빌드는 정상)으로 렌더되지 않아 미확인.

---
### #25 — 세션 3단계의 페이지 표시 통일: 독서 중에도 값은 남기고, 종료는 시작↔도착 한 줄로 ✅
- **문제(사용자 지시)**: ① 독서 중(running/paused) 화면만 페이지 표시가 달랐다 — 준비 화면의 큰 숫자가 작은 `infoRow`("시작 페이지 · 264p")로 바뀌어 같은 값인데 다른 화면처럼 보였다. ② 종료 화면은 `시작 페이지 행` + `도착 페이지 슬라이더(라벨·34pt 숫자·퍼센트·눈금·캡션)`가 세로로 쌓여 **생각·장소·지도가 한 화면에서 밀려났다.**
- **결정**:
  - **독서 중 = 준비 화면 그대로, 슬라이더만 뺀다.** 값은 이미 확정됐으니 표시 전용(누를 수 없음)이고, 잘못 잡았다면 종료 화면에서 고친다. → 세 단계가 같은 조각을 공유해 "값이 그 자리에 그대로 남아 있다"는 연속감이 생긴다.
  - **종료 = 시작·도착을 한 줄에 나란히**(`.compact`, 22pt) 두고 그 아래 **트랙 하나**. 여정의 두 끝이 한눈에 붙어 보이고 세로가 짧아진다. 퍼센트는 오른쪽 눈금 자리에 합쳐(`340쪽 중 78%`) 한 줄을 더 아낀다.
- **구현(`PageSlider.swift` 3분할)**: `PageValueField`(라벨 + 숫자 칩 + 선택적 퍼센트 · `.large`/`.compact` · `onEdit` 없으면 표시 전용) → 준비·독서 중·종료가 모두 이 조각을 쓴다. `PageSlider`(값 하나 + 트랙, 준비 전용), `PageRangeSlider`(시작·도착 한 줄 + 트랙 하나, 종료 전용). 스크럽 환산은 `Track.page(at:upper:)`로 모아 두 슬라이더가 같은 계산을 쓴다.
- **역전 방지는 그대로**: 트랙 하한 = 시작 페이지, 시작을 도착 뒤로 올리면 도착이 함께 끌려 올라간다. `PageSlider`의 `lowerLimit`은 유일한 사용처(종료)가 `PageRangeSlider`로 옮겨가 **제거**했다.
- **주의(SwiftUI)**: 알림 2개를 같은 뷰에 겹쳐 달면 하나만 산다 → 시작 쪽은 값 줄에, 도착 쪽은 본문에 나눠 붙였다.
- **상태**: ✅ 빌드 그린 · 시뮬레이터(iOS 26.5) E2E 확인 — 준비/독서 중/종료 렌더, 시작 페이지 직접 입력(264→100)에 도착 유지, 도착 알림 범위가 `100–340`으로 따라옴, 트랙 드래그 100%·하한(100p)에서 정지. 종료 화면이 짧아져 **생각·장소·지도까지 한 화면**에 들어온다.

---
*새 결정은 아래에 #26부터 이어서 기록한다.*
