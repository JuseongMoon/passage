# ARCHITECTURE — Passage

> 솔로 개발자가 수년간 유지보수하는 프로젝트. **단기 구현보다 장기 유지보수성·확장성**을 우선한다.
> 원칙: 프레임워크와 싸우지 않는다(SwiftData/SwiftUI 관용 방식 존중) · 추상화는 이득이 분명할 때만.

---

## 1. 설계 원칙
1. **Native-first** — SwiftUI · SwiftData · CloudKit · Observation · async/await · Swift 6를 관용적으로 사용.
2. **Feature 기반 모듈화** — 기능은 자기 폴더 안에서 완결. 공용만 `Core/`. Feature 간 직접 의존 금지.
3. **의존성은 한 방향** — `View → Store → Service(protocol) → Persistence/Network`. 아래 레이어는 위를 모른다.
4. **프로토콜 경계** — 외부 시스템(지도·검색·저장·인증)은 protocol로 감싸 교체·테스트 가능하게.
5. **Session is Source of Truth** — 파생 데이터를 저장하지 않는다. 통계는 세션에서 계산.

## 2. 레이어
```
┌─────────────────────────────────────────────┐
│ View (SwiftUI)   @Query(단순 조회) · @State   │
├─────────────────────────────────────────────┤
│ Store (@Observable, @MainActor)              │  ← 상태·비동기·다단계 흐름
│   ReadingSessionController · PlacePickerModel │
├─────────────────────────────────────────────┤
│ Service (protocol)                           │  ← 외부 경계 캡슐화
│   Naver · BookSearch · Location · Image · Auth│
├─────────────────────────────────────────────┤
│ Persistence(SwiftData) · Network(URLSession) │
└─────────────────────────────────────────────┘
```
규칙: View는 Store/Service를 Environment로 주입받아 사용. Service는 다른 Service를 생성자 주입으로 받는다.
쓰기(mutation)는 View에 흩뿌리지 말고 **의도가 드러나는 메서드**(예: `sessionController.stop(endPage:)`)로 캡슐화.

## 3. 폴더 구조
```
passage/
├── App/
│   ├── PassageApp.swift          @main · ModelContainer · 루트 주입
│   ├── RootView.swift            TabView (Library · Journal · Settings)
│   └── AppDependencies.swift     서비스 컨테이너(@Observable) · Environment 주입
├── Features/
│   ├── Library/                  책 목록 · 책별 통계
│   ├── Reading/                  ReadingSessionController · 시작/진행/종료 화면
│   ├── Place/                    "어디서 읽으셨나요?" · 장소 선택/생성 · 지도
│   ├── Book/                     검색 · ISBN · 수동 등록 · 책 상세
│   ├── Journal/                  Book View · Place View · Memory 상세
│   └── Settings/                 설정 · Sign in with Apple(더미)
├── Core/
│   ├── Models/                   Book.swift · ReadingSession.swift · Place.swift
│   │   └── Schema/               SchemaV1.swift · PassageMigrationPlan.swift
│   ├── Persistence/              ModelContainer+Passage.swift · (ModelActor)
│   ├── Services/
│   │   ├── Naver/                NaverMapService · NaverMapView(Representable) · Models
│   │   ├── BookSearch/           BookSearchService(protocol) + 구현
│   │   ├── Location/             LocationService
│   │   ├── ImageStore/           ImageStore(protocol) + LocalImageStore
│   │   └── Auth/                 AuthService(protocol) + DummyAuthService
│   ├── DesignSystem/             Theme · Components · Modifiers  (→ UI_GUIDE.md)
│   └── Extensions/               Date+ · View+ · …
└── Resources/                    Assets.xcassets · Localizable.xcstrings

(저장소 루트 — passage/ 소스 폴더 밖에 두어 빌드에 포함되지 않게 한다)
Config/                           Debug/Release.xcconfig · Secrets.xcconfig(gitignored)
```
> 각 Feature 폴더는 내부에 `Views/`와 자신의 Store를 둔다. 재사용 컴포넌트만 `Core/DesignSystem`으로 승격.

## 4. 데이터 모델 (SwiftData)
3개의 모델. **Session이 책·장소·시간을 잇는 원자 단위.** Book/Place는 참조 엔티티.

```swift
@Model
final class Book {
    var id: UUID = UUID()
    var title: String = ""
    var author: String = ""
    var isbn: String?
    var totalPageCount: Int?
    var coverRemoteURL: String?        // 검색 API가 준 표지 URL
    var coverImageRef: String?         // 로컬 캐시(ImageStore) 참조
    var dateAdded: Date = Date()

    // inverse. CloudKit 규칙상 관계는 optional.
    @Relationship(deleteRule: .cascade, inverse: \ReadingSession.book)
    var sessions: [ReadingSession]? = []

    init() {}
}

@Model
final class ReadingSession {           // Source of Truth
    var id: UUID = UUID()
    var startDate: Date = Date()
    var endDate: Date?                  // nil == 진행 중
    var duration: TimeInterval = 0      // 종료 시 확정 저장(일시정지 등 확장 대비)
    var startPage: Int?
    var endPage: Int?
    var note: String?                   // (Phase 2) 세션 회고 한 줄

    var book: Book?
    var place: Place?

    var isActive: Bool { endDate == nil }
    init() {}
}

@Model
final class Place {
    var id: UUID = UUID()
    var name: String = ""
    var latitude: Double?
    var longitude: Double?
    var address: String?
    var photoRefs: [String]? = []       // ImageStore 참조 목록(로컬 저장)
    var dateCreated: Date = Date()

    @Relationship(deleteRule: .nullify, inverse: \ReadingSession.place)
    var sessions: [ReadingSession]? = []

    init() {}
}
```
- **삭제 규칙**: `Book` 삭제 → 세션 cascade 삭제(그 책의 기억 제거). `Place` 삭제 → 세션의 place만 nullify(기억은 남고 장소만 사라짐).
- **파생 통계**(총 시간·세션 수·장소들)는 저장하지 않고 세션에서 계산 → `LibraryService`가 `FetchDescriptor`로 집계.

### SwiftData × CloudKit 필수 규칙 (위반 시 컨테이너 생성 실패)
- 모든 저장 속성은 **optional 또는 기본값**을 가진다. (위 모델은 전부 준수)
- `@Attribute(.unique)` **사용 불가** → 유일성은 앱 레벨에서 처리(예: ISBN으로 조회 후 있으면 재사용).
- 모든 관계는 **optional**, 그리고 **inverse를 명시**한다.
- enum을 저장하면 `RawRepresentable`(String/Int) + 기본값. (현재 모델엔 없음)
- 대용량 바이너리(사진)는 모델에 넣지 않는다 → `ImageStore`로 분리(§7).

## 5. 스키마 버전 관리 · 마이그레이션
**1일차부터** 버전 스키마를 도입한다(수년 유지보수의 핵심).
```swift
enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [Book.self, ReadingSession.self, Place.self] }
}
enum PassageMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self] }
    static var stages: [MigrationStage] { [] }   // V2 추가 시 여기에 stage 등록
}
```
컨테이너는 `Schema(versionedSchema: SchemaV1.self)` + `migrationPlan: PassageMigrationPlan.self`로 생성.
필드 추가/변경은 새 `SchemaVn`과 `MigrationStage`로. **기존 필드 삭제·타입 변경은 파괴적** → 사전 확인.

## 6. 영속성 · 동시성
- 메인 컨텍스트는 `@Environment(\.modelContext)`로 View에서 사용(메인 액터).
- `ModelContext`는 `Sendable`이 아니다 → 컨텍스트/모델을 액터 경계 넘겨 전달 금지.
- 백그라운드 대량 작업(가져오기·정리)만 `@ModelActor`로 분리. **MVP는 대부분 메인 컨텍스트로 충분.**
- Swift 6 strict concurrency. UI·모델 접근 기본 `@MainActor`.
  구조(actor/`@MainActor`) 변경은 cross-actor 브리지 핑퐁으로 큰 회귀를 낳을 수 있으므로 **작은 협력 패턴을 먼저** 시도.

## 7. 서비스 레이어 (protocol 우선)
| 서비스 | 역할 | MVP 구현 | 비고 |
|---|---|---|---|
| `NaverMapService` | reverse-geocode(좌표→주소), geocode(주소→좌표) | REST 실구현 | §8 |
| `BookSearchService` | 책 검색 · ISBN 조회 | Google Books(키 불필요) | Naver Books로 교체 가능 → DECISIONS |
| `LocationService` | 1회성 현재 위치, 권한 | CoreLocation | GPS는 선택 기능 |
| `ImageStore` | 로컬 사진 저장/로드/삭제 | `LocalImageStore`(파일) | CloudKit 동기화는 Phase 2 |
| `AuthService` | 로그인 | `DummyAuthService` | 실제 Apple 로그인은 후속 |

```swift
protocol ImageStore: Sendable {
    func save(_ data: Data) async throws -> String        // 반환: 참조 id(파일명)
    func loadData(id: String) async throws -> Data?
    func delete(id: String) async throws
}
// LocalImageStore: Application Support/PassageImages/<uuid> 에 저장, 참조 id만 SwiftData에.
```
> **사진 저장 결정**: 요구사항("로컬 저장")대로 MVP는 파일 기반 로컬 저장. 참조(id)만 동기화되고 바이너리는 로컬.
> 프로토콜 경계 덕에 후일 CloudKit 자산 동기화(`CloudImageStore`)로 교체해도 Feature 코드는 불변. (DECISIONS #9)

## 8. Naver Maps 연동 (DronePass 패턴 재사용)
**두 시스템을 분리해서 사용한다.**
### 8-1. 지도 SDK (렌더링) — 코드 인증 불필요
- SPM: `https://github.com/navermaps/SPM-NMapsMap` (upToNextMajor **3.21.0**), product **`NMapsMap`** 추가. (Geometry는 전이 의존)
- 인증: Info.plist `NMFNcpKeyId = $(NAVER_MAP_CLIENT_ID)` **한 줄로 자동 인증**. `NMFAuthManager` 코드 불필요.
- SwiftUI 사용: `UIViewRepresentable`로 `NMFNaverMapView` 래핑(**허용된 UIKit 예외**). 내부 `NMFMapView`를 콜백으로 넘겨 오버레이는 밖에서 관리(`overlay.mapView = mapView`).

### 8-2. REST (좌표↔주소) — 헤더 인증
- Host: `https://maps.apigw.ntruss.com`
- Reverse geocode(좌표→주소, 장소 주소 자동 채움):
  `GET /map-reversegeocode/v2/gc?coords={lng},{lat}&orders=roadaddr,addr&output=json`  ← **좌표는 경도,위도 순**
- Geocode(주소→좌표): `GET /map-geocode/v2/geocode?query={주소}`
- 헤더: `X-NCP-APIGW-API-KEY-ID: <client id>`, `X-NCP-APIGW-API-KEY: <client secret>`
- 키 로드: `Bundle.main.infoDictionary?["NAVER_MAP_CLIENT_ID"/"NAVER_MAP_CLIENT_SECRET"]`
- ATS 예외 불필요(HTTPS). 지도 앱 딥링크가 필요하면 `LSApplicationQueriesSchemes`에 `nmap`.

> **장소 키워드 검색(POI)** 은 별도 Naver Developers API(`openapi.naver.com`)가 필요 → MVP 제외.
> MVP 장소 생성 = 지도에서 지점 선택/현재 GPS → reverse-geocode로 주소 자동 → 사용자가 이름 지정.

## 9. Navigation
- 루트: `TabView` — **Library · Journal · Settings** (탭 최소화; calm).
- **"읽기 시작"은 탭이 아니라 액션** — Library의 책에서 시작. 진행 중에는 앱 전역에 가벼운 "읽는 중" 바(now-playing 스타일)로 경과 시간 표시.
- 탭마다 `NavigationStack` + `NavigationPath`. 목적지는 **값 기반 enum Route**로 타입 안전하게(`.navigationDestination(for:)`).
- 무거운 Coordinator는 도입하지 않는다(오버엔지니어링). 필요해지면 그때 도입.

## 10. 의존성 주입 (DI)
- `AppDependencies`(@Observable)가 서비스 프로토콜 인스턴스를 보관. 루트에서 `.environment(dependencies)` **1회 주입**.
- View/Store는 `@Environment(AppDependencies.self)`로 접근. Preview·테스트는 mock 구현으로 주입.
- 서드파티 DI 프레임워크 미사용(솔로 유지보수 단순성).

## 11. Store(ViewModel) 사용 기준
`@Observable` Store를 만드는 경우 — **다음 중 하나라도 해당**:
- 비동기 작업이 있다(검색·지오코딩·저장 흐름)
- 여러 화면/단계에 걸친 상태가 있다(활성 세션, 장소 선택 플로우)
- View identity가 바뀌어도 유지돼야 하는 상태다

그 외 **단순 목록/상세는 View + `@Query` + `@State`** 로 충분. → 불필요한 ViewModel 금지.
예: `ReadingSessionController`(활성 세션·타이머·복원), `PlacePickerModel`(검색/선택/생성), `BookSearchModel`.

## 12. 에러 처리 · 상태 표현
- 사용자 대면 에러는 **조용하고 비차단적**으로(인라인 안내, 공포스러운 alert 지양). 카피는 부드럽게.
- 로딩은 은은하게, Empty State는 따뜻한 회상 톤(→ UI_GUIDE). 세부는 `Docs/UI_GUIDE.md`.
- 도메인 에러는 작은 `enum AppError`로 타입화.

## 13. 테스트
- **Swift Testing**(`import Testing`, `@Test`, `#expect`).
- SwiftData는 `ModelConfiguration(isStoredInMemoryOnly: true)`로 인메모리 테스트. **주의: `mainContext`는 컨테이너를 강하게 보유하지 않으므로 테스트에서 컨테이너를 로컬 변수로 보유한 채 context를 써야 한다**(임시 컨테이너를 쓰면 해제되어 트랩).
- 서비스는 프로토콜 mock으로. 우선 테스트 대상: 세션 duration 계산, Library 통계 집계, reverse-geocode 파싱, 장소 dedup.

## 14. 코드 스타일
- Swift API Design Guidelines 준수. 명료함 > 간결함.
- 파일 1개 = 주요 타입 1개 원칙(확장은 같은 파일 가능).
- 강제 언래핑(`!`)·`fatalError` 지양(컨테이너 초기화 등 불가피한 곳만).
- 매직 넘버 금지 → DesignSystem 토큰/상수.
- 주변 코드 스타일(주석 밀도·네이밍)에 맞춘다.

---

## 부록 A. 프로젝트 세팅 체크리스트 (Xcode에서 수행)
문서화만으로 되지 않는, Xcode UI가 필요한 작업. (순서대로)

1. **폴더/그룹 생성** — §3 구조대로 그룹 생성, 템플릿 `Item.swift`·`ContentView.swift`는 실제 구현 시 교체.
2. **xcconfig 연결** — Project → Info → Configurations → Debug/Release에 `Config/Debug.xcconfig`·`Release.xcconfig` 지정.
3. **Info.plist 키 추가** (`$()` 치환):
   - `NMFNcpKeyId = $(NAVER_MAP_CLIENT_ID)`  (지도 SDK 자동 인증)
   - `NAVER_MAP_CLIENT_ID = $(NAVER_MAP_CLIENT_ID)` · `NAVER_MAP_CLIENT_SECRET = $(NAVER_MAP_CLIENT_SECRET)`  (REST용)
4. **위치 권한 문구** — 타깃 빌드 설정 `INFOPLIST_KEY_NSLocationWhenInUseUsageDescription` = "독서한 장소를 지도에 기록하기 위해 위치 정보를 사용합니다." (GPS 선택 기능)
5. **사진 권한** — 사진 첨부 시 `NSPhotoLibraryUsageDescription`(PHPicker 사용 시 불필요할 수 있음) / 카메라 사용 시 `NSCameraUsageDescription`.
6. **SPM 추가** — `SPM-NMapsMap` 3.21.0, product `NMapsMap`를 passage 타깃에 추가.
7. **CloudKit** — Signing & Capabilities에서 iCloud → CloudKit 체크, 컨테이너 `iCloud.com.ScienceFiction.passage` 생성/선택.
   `passage.entitlements`의 `com.apple.developer.icloud-container-identifiers`에 컨테이너 id 채우기(현재 빈 배열).
   Background Modes → Remote notifications(이미 Info.plist에 `remote-notification` 있음).
8. **Swift 언어 모드** — 타깃 `SWIFT_VERSION`/언어 모드를 **Swift 6**로 상향(현재 5.0).
9. **ModelContainer** — `PassageApp`에서 SchemaV1 + MigrationPlan + CloudKit 옵션으로 컨테이너 구성(§5).
10. **CloudKit 스키마 배포** — 개발 중 CloudKit Console에서 스키마 확인, 출시 전 Production으로 Deploy.

## 부록 B. 열린 결정 (구현 전 확정 필요)
- **BookSearch 제공자**: Google Books(무키, MVP) ↔ Naver Books(한국 메타데이터 우수, Naver Developers 키 필요). → DECISIONS #13
- **사진 동기화 시점**: 로컬(MVP) → CloudKit 자산(Phase 2). → DECISIONS #9
- **키워드 장소 검색(POI)**: Naver Developers 앱 등록 필요 시 Phase 2. → §8
