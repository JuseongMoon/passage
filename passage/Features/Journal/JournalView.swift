//
//  JournalView.swift
//  passage
//
//  독서여정 — "무엇을·어디서·얼마나 읽었나"를 지도로 회상한다.
//  풀블리드 지도에 책 표지를 장소마다 꽂고, 그 위로 뜬 바텀시트에 책별 여정을 세로 리스트로 쌓는다.
//  한 책을 고르면 지도는 그 책의 장소들을 점선 경로로 잇고(포커스), 나머지 행은 흐려진다.
//  시트는 손잡이를 끌어 2단(접힘/펼침)으로 여닫는다. 서재와 같은 웜 팔레트 톤. (→ DECISIONS #18)
//

import SwiftUI
import SwiftData
import CoreLocation

struct JournalView: View {
    @Query(sort: \Book.dateAdded, order: .reverse) private var books: [Book]
    @Environment(AppDependencies.self) private var dependencies
    @Environment(AppRouter.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var filter: JourneyFilter = .all
    @State private var selectedBookID: UUID?
    @State private var fallback: MapPoint?          // 좌표 없는 장소를 현재 위치로 대체
    @State private var detent: SheetDetent = .collapsed

    private enum SheetDetent { case collapsed, expanded }

    private var allJourneys: [BookJourney] { BookJourney.list(from: books) }

    var body: some View {
        NavigationStack {
            ZStack {
                PassagePalette.appBg.ignoresSafeArea()
                if allJourneys.isEmpty {
                    emptyState
                } else {
                    content
                }
            }
            .toolbar(.hidden, for: .navigationBar)   // 커스텀 헤더 사용
            .task {
                // 이미 권한이 있을 때만 조용히 취득(리플렉티브 화면에서 권한 프롬프트를 강요하지 않음).
                if fallback == nil, let coord = try? await dependencies.location.currentLocation() {
                    fallback = MapPoint(latitude: coord.latitude, longitude: coord.longitude)
                }
            }
            .navigationDestination(for: ReadingSession.self) { session in
                MemoryDetailView(session: session)
            }
            .onChange(of: router.journeyFocusRequest) { _, request in
                applyFocusRequest(request)
            }
            .onAppear { applyFocusRequest(router.journeyFocusRequest) }
        }
    }

    // MARK: 본문

    private var content: some View {
        let journeys = allJourneys
        let filtered = journeys.filter(filter.matches)
        return VStack(spacing: 0) {
            header
            GeometryReader { geo in
                let available = geo.size.height
                let collapsed = available * 0.46
                let expanded = available * 0.86
                let sheetHeight = detent == .expanded ? expanded : collapsed
                ZStack(alignment: .bottom) {
                    // 시트가 지도 하단을 덮으므로, 접힘 높이를 지도에 넘겨 카메라가
                    // 가려지지 않는 상단 영역을 기준으로 마커·경로를 중앙에 맞추게 한다.
                    JourneyMapView(
                        journeys: filtered,
                        selectedBookID: $selectedBookID,
                        fallback: fallback,
                        bottomInset: collapsed
                    )

                    sheet(all: journeys, filtered: filtered, height: sheetHeight)
                }
            }
        }
    }

    private var header: some View {
        PassageScreenHeader(
            eyebrow: "Passage",
            title: "독서여정",
            subtitle: JourneySummary(books: books).sentence
        )
    }

    private var emptyState: some View {
        VStack(spacing: 0) {
            PassageScreenHeader(eyebrow: "Passage", title: "독서여정")
            Spacer()
            ContentUnavailableView {
                Label("아직 남긴 독서가 없어요", systemImage: "map")
            } description: {
                Text("독서를 기록하면 이곳 지도에 여정이 쌓여요.")
            }
            Spacer()
        }
    }

    // MARK: 포커스 제어

    /// 서재 등에서 넘어온 포커스 요청을 소비 — 그 책을 선택하고 시트를 펼친다(책 상세).
    private func applyFocusRequest(_ request: UUID?) {
        guard let id = request else { return }
        selectedBookID = id
        detent = .collapsed   // 지도의 포커스 경로를 드러내고, 시트는 접힌 채 상단(뒤로·히어로)부터
        router.journeyFocusRequest = nil    // 1회성 요청 소비
    }

    /// 포커스 해제(전체 개요로 복귀).
    private func deselectBook() {
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) {
            selectedBookID = nil
        }
    }

    // MARK: 바텀 시트 (손잡이 + 필터 + 세로 여정 리스트)

    private func sheet(all: [BookJourney], filtered: [BookJourney], height: CGFloat) -> some View {
        VStack(spacing: 0) {
            grabber
            if let id = selectedBookID, let book = books.first(where: { $0.id == id }) {
                // 책 포커스 — 여정 기록·완독·인용구(구 BookDetailView를 여기 통합)
                BookJourneyDetailSheet(book: book, onBack: { deselectBook() })
            } else {
                filterBar(all: all)
                    .padding(.bottom, Theme.Spacing.sm)
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: Theme.Spacing.md) {
                        ForEach(filtered) { journey in
                            journeyCard(journey)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.bottom, Theme.Spacing.md)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height, alignment: .top)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20, style: .continuous)
                .fill(PassagePalette.appBg)
                .shadow(color: .black.opacity(0.14), radius: 16, x: 0, y: -3)
        )
    }

    /// 시트 손잡이 — 위/아래로 끌어 2단 전환(펼침/접힘). 리스트 스크롤과 충돌하지 않도록 이 영역만 드래그.
    private var grabber: some View {
        Capsule()
            .fill(PassagePalette.inkFaint)
            .frame(width: 40, height: 5)
            .frame(maxWidth: .infinity)
            .padding(.top, Theme.Spacing.sm)
            .padding(.bottom, Theme.Spacing.xs)
            .contentShape(.rect)
            .gesture(
                DragGesture(minimumDistance: 8)
                    .onEnded { value in
                        withAnimation(reduceMotion ? nil : .snappy(duration: 0.28)) {
                            if value.translation.height < -40 { detent = .expanded }
                            else if value.translation.height > 40 { detent = .collapsed }
                        }
                    }
            )
            .accessibilityElement()
            .accessibilityLabel(detent == .expanded ? "목록 접기" : "목록 펼치기")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction {
                withAnimation(reduceMotion ? nil : .snappy(duration: 0.28)) {
                    detent = detent == .expanded ? .collapsed : .expanded
                }
            }
    }

    private func filterBar(all: [BookJourney]) -> some View {
        HStack(spacing: Theme.Spacing.xs) {
            ForEach(JourneyFilter.allCases) { option in
                filterPill(option, count: option.count(in: all))
            }
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.md)
    }

    private func filterPill(_ option: JourneyFilter, count: Int) -> some View {
        let selected = filter == option
        return Button {
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.2)) {
                filter = option
                selectedBookID = nil            // 필터가 바뀌면 선택 해제(포커스 초기화)
            }
        } label: {
            Text("\(option.label) \(count)")
                .font(.system(size: 13, weight: selected ? .semibold : .regular))
                .foregroundStyle(selected ? PassagePalette.appBg : PassagePalette.inkMuted)
                .padding(.vertical, 7)
                .padding(.horizontal, Theme.Spacing.md)
                .background(
                    selected
                        ? AnyShapeStyle(PassagePalette.ink)
                        : AnyShapeStyle(.clear),
                    in: .capsule
                )
                .overlay {
                    if !selected {
                        Capsule().stroke(PassagePalette.hairline, lineWidth: 1)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
    }

    // MARK: 여정 카드 (가로 갤러리 — 표지 + 표지색 밑줄 악센트 · 제목 · 총시간)

    private func journeyCard(_ journey: BookJourney) -> some View {
        let isSelected = journey.id == selectedBookID
        let dimmed = selectedBookID != nil && !isSelected
        return Button {
            selectJourney(journey)
        } label: {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                cover(journey, isSelected: isSelected)
                Text(journey.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(PassagePalette.ink)
                    .lineLimit(1)
                Text(journey.totalDurationText)
                    .font(.system(size: 11))
                    .foregroundStyle(PassagePalette.inkMuted)
                    .lineLimit(1)
            }
            .frame(width: 108)
            .opacity(dimmed ? 0.45 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(journey.title), \(journey.totalDurationText), \(journey.distinctPlaceCount)곳의 여정")
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    /// 표지(있으면 이미지, 없으면 표지색) + 하단 밑줄 악센트 + 선택 시 잉크 테두리.
    private func cover(_ journey: BookJourney, isSelected: Bool) -> some View {
        Group {
            if let url = journey.coverURL, !url.isEmpty {
                BookCoverView(urlString: url)
            } else {
                journey.swatch.base
            }
        }
        .frame(width: 108, height: 144)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.black.opacity(0.15))   // 카드색과 무관하게 조화되는 밑줄 악센트
                .frame(height: 6)
        }
        .clipShape(.rect(cornerRadius: Theme.Radius.sm, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                .strokeBorder(PassagePalette.ink, lineWidth: isSelected ? 2.5 : 0)
        }
    }

    /// 갤러리 카드 탭 — 포커스 토글(선택 시 시트를 펼쳐 책 상세를 드러낸다).
    private func selectJourney(_ journey: BookJourney) {
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) {
            if journey.id == selectedBookID {
                selectedBookID = nil
            } else {
                selectedBookID = journey.id
                detent = .collapsed
            }
        }
    }
}

#Preview("빈 여정") {
    JournalView()
        .withPreviewEnvironment()
}

#Preview("여정 쌓인 지도") {
    let container = PassageModelContainer.makePreview()
    let ctx = container.mainContext

    // 서울 시내 좌표를 가진 장소들.
    let home = Place(name: "집", latitude: 37.5602, longitude: 126.9660)
    let cafe = Place(name: "연희동 카페", latitude: 37.5700, longitude: 126.9270)
    let library = Place(name: "정독도서관", latitude: 37.5796, longitude: 126.9836)
    ctx.insert(home); ctx.insert(cafe); ctx.insert(library)

    func addBook(_ title: String, _ author: String, finished: Bool) -> Book {
        let b = Book(title: title, author: author, totalPageCount: 320)
        if finished { b.finishedDate = .now }
        ctx.insert(b); return b
    }
    func addSession(_ book: Book, minutes: Double, daysAgo: Double, place: Place?, start: Int, end: Int) {
        let s = ReadingSession(book: book, startDate: Date(timeIntervalSinceNow: -86_400 * daysAgo), startPage: start)
        s.endPage = end
        s.duration = minutes * 60
        s.endDate = s.startDate.addingTimeInterval(minutes * 60)
        s.place = place
        ctx.insert(s)
    }

    let farewell = addBook("작별하지 않는다", "한강", finished: false)
    addSession(farewell, minutes: 70, daysAgo: 1, place: home, start: 88, end: 176)
    addSession(farewell, minutes: 60, daysAgo: 3, place: cafe, start: 0, end: 88)
    addSession(farewell, minutes: 40, daysAgo: 5, place: library, start: 176, end: 240)
    let years = addBook("연년세세", "황정은", finished: true)
    addSession(years, minutes: 45, daysAgo: 6, place: cafe, start: 0, end: 52)

    return JournalView()
        .modelContainer(container)
        .environment(AppDependencies())
        .environment(ReadingSessionController(modelContext: ctx))
}
