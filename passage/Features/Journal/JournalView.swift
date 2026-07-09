//
//  JournalView.swift
//  passage
//
//  독서여정 — "무엇을·어디서·얼마나 읽었나"를 지도로 회상한다.
//  책 표지를 읽은 장소에 꽂고, 한 책을 고르면 그 책의 장소들을 점선 경로로 잇는다.
//  전체/진행 중/완료 필터가 지도 마커와 카드를 함께 거른다. 서재와 같은 웜 팔레트 톤. (→ DECISIONS #18)
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
            mapHero(filtered: filtered)
            bottomPanel(all: journeys, filtered: filtered)
        }
    }

    private var header: some View {
        PassageScreenHeader(
            eyebrow: "Passage",
            title: "독서여정",
            subtitle: JourneySummary(books: books).sentence
        )
    }

    private func mapHero(filtered: [BookJourney]) -> some View {
        ZStack(alignment: .bottom) {
            JourneyMapView(journeys: filtered, selectedBookID: $selectedBookID, fallback: fallback)
                .clipShape(.rect(cornerRadius: Theme.Radius.lg, style: .continuous))
                .padding(.horizontal, Theme.Spacing.md)
            if selectedBookID != nil {
                viewAllButton
                    .padding(.bottom, Theme.Spacing.md)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .frame(maxHeight: .infinity)
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

    // MARK: 하단 패널(필터 + 카드 캐러셀)

    private func bottomPanel(all: [BookJourney], filtered: [BookJourney]) -> some View {
        VStack(spacing: Theme.Spacing.sm) {
            filterBar(all: all)
            carousel(filtered: filtered)
        }
        .padding(.top, Theme.Spacing.sm)
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
                .padding(.vertical, 6)
                .padding(.horizontal, Theme.Spacing.sm)
                .background(selected ? PassagePalette.ink : PassagePalette.cardBody, in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
    }

    private func carousel(filtered: [BookJourney]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                ForEach(filtered) { journey in
                    journeyCard(journey)
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.sm)
        }
    }

    private func journeyCard(_ journey: BookJourney) -> some View {
        let isSelected = journey.id == selectedBookID
        let dimmed = selectedBookID != nil && !isSelected
        return VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            BookCoverView(urlString: journey.coverURL)
                .frame(width: 84, height: 112)
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                        .strokeBorder(PassagePalette.warmAccent, lineWidth: isSelected ? 3 : 0)
                }
            Text(journey.totalDurationText)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(PassagePalette.ink)
                .padding(.top, 2)
            Text("\(journey.distinctPlaceCount)곳의 여정")
                .font(.system(size: 12))
                .foregroundStyle(PassagePalette.inkMuted)
        }
        .frame(width: 84, alignment: .leading)
        .opacity(dimmed ? 0.45 : 1)
        .contentShape(.rect)
        .onTapGesture {
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) {
                selectedBookID = isSelected ? nil : journey.id
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
