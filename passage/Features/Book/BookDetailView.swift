//
//  BookDetailView.swift
//  passage
//
//  "전체 여정보기" — 한 책으로 지금까지 남긴 전체 여정(세션) 기록 + 인용구.
//  서재 메뉴·회고에서 열리는 리뷰 화면. 모든 기록은 ReadingSession에서 파생. (Session is Source of Truth)
//  서재와 같은 웜 팔레트 톤. (→ DECISIONS #18)
//

import SwiftUI
import SwiftData

struct BookDetailView: View {
    let book: Book
    @State private var addingQuote = false

    /// 완료된 세션(여정)을 최신순으로.
    private var journeys: [ReadingSession] {
        (book.sessions ?? [])
            .filter { $0.endDate != nil }
            .sorted { $0.startDate > $1.startDate }
    }
    private var totalDuration: TimeInterval {
        journeys.reduce(0) { $0 + $1.duration }
    }
    private var sortedQuotes: [Quote] {
        (book.quotes ?? []).sorted { $0.dateCreated > $1.dateCreated }
    }

    var body: some View {
        ZStack {
            PassagePalette.appBg.ignoresSafeArea()

            List {
                heroSection
                journeySection
                quotesSection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)   // 시스템 리스트 배경 숨김 → appBg 노출
            .foregroundStyle(PassagePalette.ink)
            .tint(PassagePalette.warmAccent)
        }
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $addingQuote) {
            AddQuoteView(book: book)
        }
    }

    // MARK: 히어로 (표지 + 제목 + 저자 + 요약 한 줄)

    private var heroSection: some View {
        Section {
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                BookCoverView(urlString: book.coverRemoteURL)
                    .frame(width: 80, height: 120)
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text(book.title)
                        .font(.title3)
                        .fontDesign(.serif)
                        .fontWeight(.semibold)
                        .foregroundStyle(PassagePalette.ink)
                    if !book.author.isEmpty {
                        Text(book.author)
                            .font(.subheadline)
                            .foregroundStyle(PassagePalette.inkMuted)
                    }
                    if !journeys.isEmpty {
                        Text("\(journeys.count)개의 여정 · 총 \(totalDuration.readableDuration)")
                            .font(.footnote)
                            .foregroundStyle(PassagePalette.inkMuted)
                            .padding(.top, 2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, Theme.Spacing.xs)
            .listRowBackground(Color.clear)   // 히어로는 appBg 위에 바로(카드 아님)
            .listRowInsets(EdgeInsets(top: 0, leading: Theme.Spacing.md, bottom: 0, trailing: Theme.Spacing.md))
        }
    }

    // MARK: 여정 기록 (전체 세션 · 최신순)

    private var journeySection: some View {
        Section {
            if journeys.isEmpty {
                Text("아직 남긴 여정이 없어요")
                    .font(.subheadline)
                    .foregroundStyle(PassagePalette.inkMuted)
            } else {
                ForEach(journeys) { session in
                    NavigationLink {
                        MemoryDetailView(session: session)
                    } label: {
                        MemoryRow(session: session, showsBook: false)
                    }
                }
            }
        } header: {
            sectionHeader("여정 기록")
        }
        .listRowBackground(PassagePalette.cardBody)
    }

    // MARK: 인용구

    private var quotesSection: some View {
        Section {
            ForEach(sortedQuotes) { quote in
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text(quote.text)
                        .fontDesign(.serif)
                        .foregroundStyle(PassagePalette.ink)
                    if let page = quote.page {
                        Text("\(page)p")
                            .font(.caption)
                            .foregroundStyle(PassagePalette.inkFaint)
                    }
                }
                .padding(.vertical, Theme.Spacing.xxs)
            }
            Button {
                addingQuote = true
            } label: {
                Label("인용구 추가", systemImage: "quote.opening")
                    .foregroundStyle(PassagePalette.warmAccent)
            }
        } header: {
            sectionHeader("인용구")
        }
        .listRowBackground(PassagePalette.cardBody)
    }

    // MARK: 헬퍼

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(PassagePalette.inkMuted)
            .textCase(nil)
    }
}

#Preview("여정 쌓인 책") {
    let container = PassageModelContainer.makePreview()
    let ctx = container.mainContext

    let book = Book(title: "작별하지 않는다", author: "한강", totalPageCount: 340)
    ctx.insert(book)
    let home = Place(name: "집"); let cafe = Place(name: "연희동 카페")
    ctx.insert(home); ctx.insert(cafe)

    func addSession(minutes: Double, daysAgo: Double, place: Place?, start: Int, end: Int) {
        let s = ReadingSession(book: book, startPage: start)
        s.endPage = end
        s.duration = minutes * 60
        s.startDate = Date(timeIntervalSinceNow: -86_400 * daysAgo)
        s.endDate = s.startDate.addingTimeInterval(minutes * 60)
        s.place = place
        ctx.insert(s)
    }
    addSession(minutes: 70, daysAgo: 1, place: home, start: 176, end: 264)
    addSession(minutes: 60, daysAgo: 4, place: cafe, start: 88, end: 176)
    addSession(minutes: 55, daysAgo: 7, place: cafe, start: 0, end: 88)

    ctx.insert(Quote(text: "눈은 내리고, 나는 그 애의 손을 오래 생각했다.", page: 132, book: book))

    return NavigationStack {
        BookDetailView(book: book)
    }
    .modelContainer(container)
    .environment(AppDependencies())
    .environment(ReadingSessionController(modelContext: ctx))
}
