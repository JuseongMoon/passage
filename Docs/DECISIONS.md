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

### #9 — 사진: 로컬 저장 우선(ImageStore 추상화) 🔵
- **결정**: 사진은 `ImageStore` 프로토콜 뒤에 두고, MVP는 파일 기반 `LocalImageStore`(Application Support). SwiftData엔 참조 id만.
- **이유**: 요구사항("로컬 저장") 충족, CloudKit 용량/동기화 복잡성 회피, 바이너리를 DB 밖으로.
- **트레이드오프**: MVP에선 사진이 기기 로컬(타 기기에 미동기화 → placeholder). **재검토**: Phase 2에 `CloudImageStore`(CKAsset)로 교체 — 프로토콜 덕에 Feature 코드 불변.

### #10 — 시크릿 관리: gitignored Secrets.xcconfig ✅
- **결정**: 네이버 키 등은 `passage/App/Config/Secrets.xcconfig`(gitignore)에 두고 Info.plist `$()` 치환으로 주입. `.example` 템플릿 커밋. 소스 폴더 안이므로 xcconfig들을 **target membership 예외**(pbxproj)로 두어 앱 번들 유출을 막는다.
- **이유**: DronePass 검증 패턴. 코드/저장소에 시크릿 노출 방지.
- **영향**: 새 환경은 `.example` 복사 후 값 입력. 값 하드코딩 금지.

### #11 — Sign in with Apple: MVP 더미 🔵
- **결정**: MVP는 더미 버튼만. `AuthService` 프로토콜로 감싸 실제 연동은 후속.
- **이유**: 데이터 정체성은 이미 iCloud(CloudKit)에 묶임 → 로그인은 데이터 게이팅용이 아니라 향후 계정/프로필용. 나머지 완성 후 연결.
- **트레이드오프**: 초기엔 로그인 무동작. 프로토콜 경계로 교체 비용 최소화.

### #12 — VersionedSchema + MigrationPlan 1일차 도입 ✅
- **결정**: 처음부터 `SchemaV1` + `PassageMigrationPlan` 구성.
- **이유**: 수년 유지보수에서 모델은 반드시 변한다. 나중에 도입하면 초기 스키마 버저닝 소급이 어렵다.
- **영향**: 필드 변경은 새 `SchemaVn` + `MigrationStage`. 파괴적 변경 전 확인.

### #13 — BookSearch 제공자: Google Books + API 키 🔵
- **결정**: `BookSearchService` 프로토콜 뒤 `GoogleBooksSearchService`. 파싱(테스트 3종)·검색 UI(`BookSearchView`)·표지(`BookCoverView`) 구현·검증 완료.
- **발견(2026-07-04)**: **키 없는 Google Books는 공용 익명 할당량 초과(HTTP 429)** 로 실사용 불가 → **무료 API 키 필요**(Google Cloud Console, 하루 1000). `GOOGLE_BOOKS_API_KEY`를 Secrets.xcconfig·Info.plist에 넣으면 즉시 동작(코드는 키 있으면 자동 사용).
- **대안(프로토콜 유지로 교체 저렴)**: **Naver 책 검색**(developers.naver.com 별도 등록 — 지도용 Cloud Platform과 다름, 한국 메타데이터·표지 최적) 또는 Kakao. 한국 앱이면 Naver 유력.
- 수동 등록(`AddBookView` "직접 입력")은 항상 가능한 오프라인 경로.

---
### #14 — Swift 6 + Main Actor 기본 격리 ✅
- **결정**: Swift 6 language mode. 모듈 기본 액터 격리는 **MainActor**(Xcode 26 신규 템플릿 기본값 유지). UI·모델·대부분 서비스는 자동 MainActor, 오프메인이 필요한 IO 서비스만 명시적 `actor`(ImageStore·Auth).
- **이유**: SwiftUI/SwiftData와 마찰 최소, 크로스액터 브리지 회귀 위험 감소(작업 지침과 일치). 명시적 격리는 필요한 곳에만.
- **트레이드오프**: 네트워크/디코딩도 기본 MainActor(작은 페이로드라 무해). 커지면 그 지점만 `nonisolated`로 오프메인 전환. NaverMapService가 이 사유로 `@MainActor`.
- **@Model은 반드시 `nonisolated`**: SwiftData가 내부 스레드(특히 CloudKit 백그라운드 동기화)에서 모델에 접근하므로, MainActor 기본 격리를 받지 않도록 모든 `@Model`을 `nonisolated`로 표시한다. (미표시 시 오프메인 접근에서 런타임 트랩)

---
*새 결정은 아래에 #15부터 이어서 기록한다.*
