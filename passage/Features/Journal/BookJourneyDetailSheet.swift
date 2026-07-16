//
//  BookJourneyDetailSheet.swift
//  passage
//
//  독서여정 "책 포커스" 시트 — 한 책의 여정 기록·완독 표시·인용구.
//  지도가 장소 경로(어디서·얼마나)를 담당하고, 이 시트는 세션별 기억과 인용구를 담는다.
//  별도 상세 화면(구 BookDetailView) 대신 독서여정 지도에 통합한 형태. (→ passage-v2-update-plan)
//  모든 기록은 ReadingSession에서 파생. Session is Source of Truth.
//

import SwiftUI
import SwiftData

struct BookJourneyDetailSheet: View {
    let book: Book
    /// "‹ 모든 책 보기" — 포커스 해제(전체 개요로 복귀).
    let onBack: () -> Void

    @Environment(\.modelContext) private var modelContext
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
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                backButton
                hero
                journeySection
                quotesSection
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .sheet(isPresented: $addingQuote) {
            AddQuoteView(book: book)
        }
    }

    // MARK: 뒤로 (모든 책 보기)

    private var backButton: some View {
        Button(action: onBack) {
            HStack(spacing: 2) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
                Text("모든 책 보기")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundStyle(PassagePalette.inkMuted)
        }
        .buttonStyle(.plain)
        .padding(.top, Theme.Spacing.xs)
        .accessibilityHint("전체 여정 개요로 돌아갑니다")
    }

    // MARK: 히어로 (표지 + 제목 + 저자 + 요약 + 완독 토글)

    private var hero: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            BookCoverView(urlString: book.coverRemoteURL)
                .frame(width: 64, height: 96)
                .clipShape(.rect(cornerRadius: 5, style: .continuous))
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
                finishToggle
                    .padding(.top, Theme.Spacing.xs)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: 완독 표시 (진행 중 ↔ 다 읽음)

    private var finishToggle: some View {
        Button {
            book.finishedDate = book.isFinished ? nil : .now
            try? modelContext.save()
        } label: {
            HStack(spacing: Theme.Spacing.xxs) {
                Image(systemName: book.isFinished ? "checkmark.seal.fill" : "book")
                Text(book.isFinished ? "다 읽음" : "읽는 중")
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(book.isFinished ? PassagePalette.appBg : PassagePalette.ink)
            .padding(.vertical, 6)
            .padding(.horizontal, Theme.Spacing.sm)
            .background(book.isFinished ? PassagePalette.warmAccent : PassagePalette.cardBody, in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(book.isFinished ? "다 읽음으로 표시됨. 눌러서 해제" : "읽는 중. 눌러서 다 읽음으로 표시")
    }

    // MARK: 여정 기록 (완료 세션 · 최신순 → 개별 기억 상세)

    private var journeySection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            sectionHeader("여정 기록")
            if journeys.isEmpty {
                Text("아직 남긴 여정이 없어요")
                    .font(.subheadline)
                    .foregroundStyle(PassagePalette.inkMuted)
                    .padding(.horizontal, Theme.Spacing.sm)
            } else {
                VStack(spacing: 0) {
                    ForEach(journeys) { session in
                        NavigationLink(value: session) {
                            HStack(spacing: Theme.Spacing.sm) {
                                MemoryRow(session: session, showsBook: false)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(PassagePalette.inkFaint)
                            }
                            .padding(.horizontal, Theme.Spacing.sm)
                            .padding(.vertical, Theme.Spacing.xs)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        if session.id != journeys.last?.id {
                            Divider().overlay(PassagePalette.hairline)
                                .padding(.leading, Theme.Spacing.sm)
                        }
                    }
                }
                .background(PassagePalette.cardBody, in: .rect(cornerRadius: Theme.Radius.md, style: .continuous))
            }
        }
    }

    // MARK: 인용구

    private var quotesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            sectionHeader("인용구")
            VStack(alignment: .leading, spacing: 0) {
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
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Theme.Spacing.sm)
                    Divider().overlay(PassagePalette.hairline)
                        .padding(.leading, Theme.Spacing.sm)
                }
                Button {
                    addingQuote = true
                } label: {
                    Label("인용구 추가", systemImage: "quote.opening")
                        .font(.subheadline)
                        .foregroundStyle(PassagePalette.warmAccent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Theme.Spacing.sm)
                }
                .buttonStyle(.plain)
            }
            .background(PassagePalette.cardBody, in: .rect(cornerRadius: Theme.Radius.md, style: .continuous))
        }
    }

    // MARK: 헬퍼

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(PassagePalette.inkMuted)
    }
}

#Preview("책 포커스 시트") {
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
    ctx.insert(Quote(text: "눈은 내리고, 나는 그 애의 손을 오래 생각했다.", page: 132, book: book))

    return NavigationStack {
        BookJourneyDetailSheet(book: book, onBack: {})
            .navigationDestination(for: ReadingSession.self) { MemoryDetailView(session: $0) }
    }
    .modelContainer(container)
    .environment(AppDependencies())
}
