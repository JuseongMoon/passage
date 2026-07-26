# UI GUIDE — Passage

> 지향: **Calm · Minimal · Beautiful · Reflective** (Apple Journal / Books / Day One).
> 원칙: **덜 넣는다.** 여백을 아끼지 않는다. 네이티브(Apple HIG)를 최대한 따른다. 커스텀은 이유가 있을 때만.

> ⚠️ **2026-07 보딩패스 재구성(DECISIONS #15) + 톤 통일(#18)**: **전 탭(서재·독서여정·설정)이 웜 `PassagePalette` 톤을 공유한다** — 웜 `appBg` 배경 · 커스텀 대형 잉크 헤더(`PassageScreenHeader`) · `ink/inkMuted` 텍스트 · `cardBody` 카드 · `warmAccent`. **티켓/바코드/원형시계 모티프는 독서 루프 표면(서재 홈 · 세션 오버레이 · 책 추가)에 한정**(설정 등엔 강요하지 않는다 — Calm·Minimal). 아래 뉴트럴·시스템색·Dynamic Type 지침은 이제 **팔레트만 웜 토큰으로 치환**해 읽는다(구조/여백/타이포 원칙은 동일). 고정 pt는 dense 레이아웃(티켓·타이머)에만 예외. 철학(Calm·Reflective, Memory over Productivity)은 전 화면 동일.

---

## 1. Typography
- **시스템 텍스트 스타일**을 기본으로(Dynamic Type 필수): `largeTitle · title · title2 · headline · body · callout · subheadline · footnote · caption`.
- 절대 고정 pt로 크기를 박지 않는다. 항상 `.font(.headline)` 형태.
  - **예외(재구성, DECISIONS #15)**: 패스 티켓·원형 타이머 등 dense 레이아웃은 목업 비례 유지를 위해 고정 pt 허용. 대신 VoiceOver 라벨·다크모드·Reduce Motion은 유지한다.
- **독서적 감성**: 책 제목·인용·회상 표시 텍스트는 `.fontDesign(.serif)`로 문학적 톤. 일반 UI는 기본 SF.
- 굵기 남용 금지. 위계는 크기·색·여백으로. Bold는 강조 1곳.
- 숫자(통계·시간)는 `.monospacedDigit()`로 흔들림 방지.

## 2. Spacing — 4pt 그리드
| 토큰 | 값 | 용도 |
|---|---|---|
| `xxs` | 4 | 아이콘-라벨 간격 |
| `xs` | 8 | 밀접 요소 |
| `sm` | 12 | 리스트 행 내부 |
| `md` | 16 | **기본** 여백/패딩 |
| `lg` | 24 | 섹션 간 |
| `xl` | 32 | 화면 상하 여백 |
| `xxl` | 48 | 큰 호흡, Empty State |
`Theme.Spacing`로 상수화. 화면 좌우 기본 패딩 `md`(16). 여백은 넉넉하게 — 답답함은 calm을 깬다.

## 3. Color
- **뉴트럴 중심 + 단일 웜 액센트.** 다채로운 색은 피한다.
- 배경: 시스템 배경 사용 — `Color(.systemGroupedBackground)` / `Color(.secondarySystemGroupedBackground)`. (다크모드 자동)
- 텍스트: `.primary` / `.secondary` / `.tertiary`. 하드코딩 색 금지.
- **Accent**: 잉크/따뜻한 앰버 계열 하나. `Assets.xcassets`의 `AccentColor` 컬러셋으로 정의(라이트/다크 각각). 앱 전역 tint.
- 라이트/다크 **둘 다** 반드시 검수. 대비(명암비) 접근성 기준 충족.
- **웜 팔레트(DECISIONS #15·#18)**: **전 화면**이 `Core/DesignSystem/PassagePalette.swift`의 웜 토큰(라이트/다크 정의)을 쓴다 — 뉴트럴(`appBg·cardBody·ink·inkMuted·hairline·field…`)·액센트(`warmAccent·danger`). 책별 `Swatch`(book.id 결정적)는 **독서 루프(서재 패스·세션)에 한정**. **여전히 하드코딩 금지** — 색은 반드시 이 토큰으로.
- **화면 모드(DECISIONS #16)**: 설정에서 시스템/라이트/다크 선택, **기본=시스템**. `AppearanceMode` + `RootView.preferredColorScheme` + `@AppStorage("appearanceMode")`.

## 4. Corner Radius
`.rect(cornerRadius:style: .continuous)` (연속 곡률) 사용.
| 토큰 | 값 | 용도 |
|---|---|---|
| `sm` | 8 | 작은 버튼·태그 |
| `md` | 12 | 리스트 카드·입력 |
| `lg` | 16 | 큰 카드·시트 |
| `xl` | 24 | 표지·히어로 |
`Theme.Radius`로 상수화. 값 혼용 금지.

## 5. Animation
- 기본은 **부드럽고 짧게**: `.smooth`/`.snappy` 스프링, 0.2–0.35s. 화려한 전환 금지.
- 상태 변화·등장은 은은하게(fade/scale 소폭). "튀는" 모션 지양.
- **Reduce Motion 존중** — `@Environment(\.accessibilityReduceMotion)` 확인 후 모션 축소.
- 타이머 등 반복 애니메이션은 과하지 않게(읽는 중 화면은 특히 정적으로).

## 6. Navigation
- `NavigationStack` + 값 기반 라우팅. `TabView`(Library · Journal · Settings).
- 시트는 회상/입력 흐름에, 풀스크린 커버는 몰입(읽는 중)에.
- 시트 detent는 `.medium`/`.large` 적절히. 큰 제목(`.navigationBarTitleDisplayMode`)은 화면 성격에 맞춰.
- 네이티브 내비게이션/재질(자연스러운 반투명·깊이)을 그대로 활용. 임의 재현 금지.
  단 **배포 타깃은 iOS 18.6** — OS 전용 재질·컨트롤을 쓰기 전 가용 버전을 확인한다(→ DECISIONS #5 정정).

## 7. Component 규칙
- 2곳 이상에서 쓰이면 `Core/DesignSystem/Components`로 승격, 아니면 Feature 로컬.
- 공용 후보: `PrimaryButton` · `Card` · `BookCoverView` · `StatLabel` · `SessionRow` · `PlaceRow` · `TimerView` · `EmptyStateView` · `TagChip`.
- 컴포넌트는 색·간격·radius를 **토큰으로만** 참조. 내부에 매직 넘버 금지.
- 버튼은 역할별 스타일(primary/secondary/plain) 통일. 파괴적 동작만 `.role(.destructive)`.

## 8. Empty State
비어 있음은 실패가 아니라 **초대**다. 따뜻하고 조용하게.
- 구성: 은은한 SF Symbol(가늘게) + 한 줄 제목 + 부드러운 설명 + (선택)행동 1개.
- 카피 예: "아직 남긴 독서가 없어요" / "첫 책을 더해 첫 기억을 만들어 보세요."
- 압박·수치·목표 언급 금지. 느낌표·명령형 지양.

## 9. Loading
- 전체 화면 스피너 지양. **은은하게**(부분 리덕션, 표지 자리 placeholder, `.redacted(reason: .placeholder)`).
- 짧은 지연이면 아무것도 보이지 않아도 된다(깜빡임 방지). 필요 시 지연 후 표시.
- 검색 등은 인라인 소형 인디케이터.

## 10. Error
- **비차단·인라인** 우선. 파괴적 alert 남용 금지.
- 카피는 사람 말투로, 원인+다음 행동. 예: "책 정보를 불러오지 못했어요. 잠시 후 다시 시도해 주세요."
- 네트워크 실패해도 앱은 조용히 회복. 사용자를 탓하지 않는다.
- 되돌릴 수 없는 삭제만 확인. 확인 문구도 담백하게.

## 11. 접근성 (기본값)
- Dynamic Type 전 구간 대응(잘림 검수). VoiceOver 라벨·힌트 제공.
- 탭 타깃 최소 44×44pt. 색만으로 정보 전달 금지(아이콘/텍스트 병행).
- 명암비 준수. Reduce Motion / Increase Contrast 대응.

---
정리: **의심되면 덜 넣는다.** 화려함보다 고요함. 이 앱의 아름다움은 여백과 절제에서 온다.
