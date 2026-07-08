//
//  JournalView.swift
//  passage
//
//  저널 — 독서 기억의 타임라인. 책/장소 렌즈로 묶어 본다. 탭하면 Memory 상세.
//  서재와 같은 웜 팔레트 톤(appBg·커스텀 헤더·cardBody 카드). (→ DECISIONS #18)
//

import SwiftUI
import SwiftData

struct JournalView: View {
    @Query(
        filter: #Predicate<ReadingSession> { $0.endDate != nil },
        sort: \ReadingSession.startDate,
        order: .reverse
    ) private var sessions: [ReadingSession]

    @State private var lens: JournalLens = .book
    @State private var showingReflection = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            ZStack {
                PassagePalette.appBg.ignoresSafeArea()

                if sessions.isEmpty {
                    emptyState
                } else {
                    content
                }
            }
            .toolbar(.hidden, for: .navigationBar)   // 커스텀 헤더 사용
            .sheet(isPresented: $showingReflection) {
                ReflectionView()
            }
        }
    }

    // MARK: 본문

    private var content: some View {
        VStack(spacing: 0) {
            PassageScreenHeader(
                title: "독서여정",
                subtitle: "\(sessions.count)개의 기억"
            ) {
                reflectionButton
            }
            lensPicker
            memoryList
        }
    }

    private var emptyState: some View {
        VStack(spacing: 0) {
            PassageScreenHeader(title: "독서여정")
            Spacer()
            ContentUnavailableView {
                Label("아직 남긴 독서가 없어요", systemImage: "book.closed")
            } description: {
                Text("독서를 마치면 이곳에 기억이 쌓여요.")
            }
            Spacer()
        }
    }

    // MARK: 회고 액션

    private var reflectionButton: some View {
        Button { showingReflection = true } label: {
            HStack(spacing: Theme.Spacing.xxs) {
                Image(systemName: "sparkles")
                Text("회고")
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(PassagePalette.ink)
            .padding(.vertical, 6)
            .padding(.horizontal, Theme.Spacing.sm)
            .background(PassagePalette.cardBody, in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("회고 보기")
    }

    // MARK: 렌즈(책/장소) 세그먼트

    private var lensPicker: some View {
        HStack(spacing: 0) {
            ForEach(JournalLens.allCases) { option in
                let selected = lens == option
                Button {
                    withAnimation(reduceMotion ? nil : .snappy(duration: 0.2)) {
                        lens = option
                    }
                } label: {
                    Text(option.label)
                        .font(.system(size: 14, weight: selected ? .semibold : .regular))
                        .foregroundStyle(selected ? PassagePalette.appBg : PassagePalette.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background {
                            if selected { Capsule().fill(PassagePalette.ink) }
                        }
                        .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
            }
        }
        .padding(4)
        .background(PassagePalette.cardBody, in: .capsule)
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.top, Theme.Spacing.xs)
        .padding(.bottom, Theme.Spacing.sm)
    }

    // MARK: 기억 리스트

    private var memoryList: some View {
        List {
            ForEach(MemoryOrganizer.grouped(sessions, by: lens)) { group in
                Section {
                    ForEach(group.sessions) { session in
                        NavigationLink {
                            MemoryDetailView(session: session)
                        } label: {
                            MemoryRow(session: session, showsBook: lens == .place)
                        }
                        .listRowBackground(PassagePalette.cardBody)
                    }
                } header: {
                    Text(group.title)
                        .font(.system(size: 13))
                        .foregroundStyle(PassagePalette.inkMuted)
                        .textCase(nil)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)   // 시스템 리스트 배경 숨김 → appBg 노출
    }
}

#Preview("빈 저널") {
    JournalView()
        .withPreviewEnvironment()
}

#Preview("기억 쌓인 저널") {
    let container = PassageModelContainer.makePreview()
    let ctx = container.mainContext

    let home = Place(name: "집"); let cafe = Place(name: "연희동 카페")
    ctx.insert(home); ctx.insert(cafe)

    func addBook(_ title: String, _ author: String) -> Book {
        let b = Book(title: title, author: author, totalPageCount: 320)
        ctx.insert(b); return b
    }
    func addSession(_ book: Book, minutes: Double, daysAgo: Double, place: Place?, start: Int, end: Int) {
        let s = ReadingSession(book: book, startPage: start)
        s.endPage = end
        s.duration = minutes * 60
        s.startDate = Date(timeIntervalSinceNow: -86_400 * daysAgo)
        s.endDate = s.startDate.addingTimeInterval(minutes * 60)
        s.place = place
        ctx.insert(s)
    }

    let farewell = addBook("작별하지 않는다", "한강")
    addSession(farewell, minutes: 70, daysAgo: 1, place: home, start: 88, end: 176)
    addSession(farewell, minutes: 60, daysAgo: 3, place: cafe, start: 0, end: 88)
    let years = addBook("연년세세", "황정은")
    addSession(years, minutes: 45, daysAgo: 5, place: cafe, start: 0, end: 52)

    return JournalView()
        .modelContainer(container)
        .environment(AppDependencies())
        .environment(ReadingSessionController(modelContext: ctx))
}
