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
*새 결정은 아래에 #22부터 이어서 기록한다.*
