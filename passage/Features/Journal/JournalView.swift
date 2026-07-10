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
                    JourneyMapView(journeys: filtered, selectedBookID: $selectedBookID, fallback: fallback)

                    if selectedBookID != nil && detent == .collapsed {
                        viewAllButton
                            .padding(.bottom, collapsed + Theme.Spacing.sm)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

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

    // MARK: 지도 위 "전체 여정보기" (포커스 → 개요 복귀)

    private var viewAllButton: some View {
        Button {
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) {
                selectedBookID = nil
            }
        } label: {
            Text("전체 여정보기")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(PassagePalette.appBg)
                .padding(.vertical, 10)
                .padding(.horizontal, Theme.Spacing.lg)
                .background(PassagePalette.ink, in: .capsule)
                .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: 바텀 시트 (손잡이 + 필터 + 세로 여정 리스트)

    private func sheet(all: [BookJourney], filtered: [BookJourney], height: CGFloat) -> some View {
        VStack(spacing: 0) {
            grabber
            filterBar(all: all)
                .padding(.bottom, Theme.Spacing.sm)
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filtered) { journey in
                        journeyRow(journey)
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.lg)
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

    // MARK: 여정 행 (표지 + 제목·저자 · 총시간 · N곳의 여정)

    private func journeyRow(_ journey: BookJourney) -> some View {
        let isSelected = journey.id == selectedBookID
        let dimmed = selectedBookID != nil && !isSelected
        return VStack(spacing: 0) {
            HStack(spacing: Theme.Spacing.md) {
                BookCoverView(urlString: journey.coverURL)
                    .frame(width: 52, height: 68)
                    .clipShape(.rect(cornerRadius: 5, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .strokeBorder(PassagePalette.ink, lineWidth: isSelected ? 2.5 : 0)
                    }
                VStack(alignment: .leading, spacing: 3) {
                    Text(journey.title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(PassagePalette.ink)
                        .lineLimit(1)
                    if !journey.author.isEmpty {
                        Text(journey.author)
                            .font(.system(size: 12))
                            .foregroundStyle(PassagePalette.inkMuted)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: Theme.Spacing.sm)
                VStack(alignment: .trailing, spacing: 3) {
                    Text(journey.totalDurationText)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(PassagePalette.ink)
                        .lineLimit(1)
                    Text("\(journey.distinctPlaceCount)곳의 여정")
                        .font(.system(size: 12))
                        .foregroundStyle(PassagePalette.inkMuted)
                        .lineLimit(1)
                }
            }
            .padding(.vertical, Theme.Spacing.sm)
            Rectangle()
                .fill(PassagePalette.hairline)
                .frame(height: 1)
        }
        .opacity(dimmed ? 0.4 : 1)
        .contentShape(.rect)
        .onTapGesture {
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) {
                if isSelected {
                    selectedBookID = nil
                } else {
                    selectedBookID = journey.id
                    detent = .collapsed        // 선택하면 시트를 접어 지도의 포커스 경로를 드러낸다
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(journey.title), \(journey.totalDurationText), \(journey.distinctPlaceCount)곳의 여정")
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
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
