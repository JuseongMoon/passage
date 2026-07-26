# CLAUDE.md — Passage

> 항상 읽는 문서. 간결 유지(토큰 절약). 상세 내용은 `Docs/`의 개별 문서로 분리한다.

## 1. 프로젝트
Passage는 **Reading Memory App**이다. 무엇을 · 어디서 · 얼마나 · 언제 읽었는지를 기록해
**독서를 삶의 기억으로 남긴다.** 생산성/독서관리 앱이 아니다.

**핵심 철학 — Memory over Productivity**

- 절대 만들지 않는다: Reading Goals · Streak · Gamification · 경쟁 · Dashboard 중심 UI · 사용자 압박
- 항상 지향한다: **Calm · Minimal · Beautiful · Reflective** (Apple Journal / Books / Day One 감성)

## 2. 기술 스택
SwiftUI · SwiftData(+CloudKit private sync) · Observation(`@Observable`) · async/await · **Swift 6** · **iOS 18.6+**
- ⚠️ **앱 배포 타깃은 iOS 18.6**이다(프로젝트/테스트 타깃 설정값 26.5에 속지 말 것 — 앱 타깃이 덮어쓴다).
  최신 API를 쓰기 전에 **가용 버전을 반드시 확인**한다. iOS 26 전용 API(예: `Slider(neutralValue:enabledBounds:)`)는 쓸 수 없다.
- 지도: **Naver Maps** SDK(`NMapsMap`, SPM) + REST(geocode / reverse-geocode)
- UIKit은 `UIViewRepresentable` 브리지 등 **불가피한 경우만** (지도 뷰가 대표적 예외)
- 테스트: **Swift Testing**

## 3. 아키텍처 요약
- **레이어(의존성 한 방향 ↓)**: `View` → `@Observable Store` → `Service(protocol)` → `SwiftData / Network`
- **Feature 기반 구조**: 기능별 폴더. 공용 코드만 `Core/`. Feature끼리 서로 import 금지.
- **MV 하이브리드**: 상태·비동기·다단계 흐름은 `@Observable` Store, 단순 조회 화면은 View에서 `@Query`.
  → **View마다 ViewModel을 강제하지 않는다.**
- **Repository 미사용**: SwiftData 관용 방식(`@Query` / `FetchDescriptor`) + 의도가 드러나는 도메인 서비스 메서드로 쓰기 캡슐화.
- **Session is Source of Truth**: 모든 통계·저널은 `ReadingSession`에서 파생한다. 활성 세션은 **시작 즉시 저장**(앱 종료·크래시에도 유지).

## 4. 프로젝트 구조
```
passage/
  App/         진입점 · Root TabView · DI(AppDependencies)
  Features/    Library · Reading · Place · Book · Journal · Settings
  Core/
    Models/       Book · ReadingSession · Place  (+ Schema/ Migration)
    Persistence/  ModelContainer 구성 · (필요 시 ModelActor)
    Services/     Naver · BookSearch · Location · ImageStore · Auth
    DesignSystem/ Theme · Components · Modifiers
    Extensions/
  App/Config/  *.xcconfig · Secrets.xcconfig(gitignored) — target membership 예외로 번들 제외
  Resources/   Assets · Localizable(.xcstrings)
```

## 5. 코딩 규칙
- **동시성**: Swift 6 strict concurrency. UI·Model 접근은 기본 `@MainActor`. 백그라운드 대량 작업만 `@ModelActor`.
  구조(actor/`@MainActor`) 변경은 **신중히** — 작은 협력 패턴(yield, priority 조정)을 먼저 시도한다.
- **SwiftData × CloudKit**: 모든 저장 속성은 `optional` 또는 **기본값**. `@Attribute(.unique)` **금지**(앱단 dedup). 관계는 `optional` + **inverse 필수**.
- **서비스는 protocol 우선**(테스트·교체 용이). 주입은 `AppDependencies`를 Environment로 1회 주입.
- **네이밍**: 타입 UpperCamel, 그 외 lowerCamel. `~View` / `~Store`·`~Model`·`~Controller` / `~Service`.
- **UI 문구는 한국어.** Dynamic Type · 접근성(VoiceOver) · 다크모드 항상 지원.
- **시크릿**: `Secrets.xcconfig`(gitignored)에만. 코드·문서·커밋에 값 하드코딩 금지.

## 6. 반드시 지킬 원칙
1. Gamification · 목표 · 스트릭 · 경쟁 · 대시보드를 **추가하지 않는다.** 새 기능은 "이게 기억을 돕는가?"로 판단.
2. Calm · Minimal을 해치면 넣지 않는다. **의심되면 덜 넣는다.**
3. 스키마 변경은 `VersionedSchema` + `MigrationPlan`으로. **파괴적 변경 전 사용자 확인.**
4. 리팩토링·기능 제거 전 전체 grep으로 영향도 분석, 대안 먼저 검토.
5. 코드 변경 후 **전체 빌드**로 컴파일 확인, 데이터 흐름은 실제 데이터로 검증.
6. 주요 결정은 `Docs/DECISIONS.md`에 기록하고 문서를 최신으로 유지.

## 7. 문서 맵
제품 `Docs/PRD.md` · 구조/세팅 `Docs/ARCHITECTURE.md` · 디자인 `Docs/UI_GUIDE.md` · 로드맵 `Docs/ROADMAP.md` · 결정 `Docs/DECISIONS.md`
