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

    @State private var addingQuote = false

    /// 완료된 세션(여정)을 **오래된 순**으로 — 목업의 순번(1., 2., …)이 곧 여정의 순서다.
    private var journeys: [ReadingSession] {
        (book.sessions ?? [])
            .filter { $0.endDate != nil }
            .sorted { $0.startDate < $1.startDate }
    }

    /// 진행률·총시간 등 파생값. 지도·갤러리와 같은 규칙을 쓰려고 BookJourney를 그대로 쓴다.
    private var journey: BookJourney { BookJourney(book: book) }
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

    /// 표지 + 제목/저자 + **총 독서시간(크게)** + 진행률. 이 화면의 주인공은 "얼마나 함께했나"다.
    /// 완독 토글은 서재 카드 ⋮ 메뉴로 옮겼다 — 여정 탭은 되돌아보는 화면으로 비운다. (→ #27 결정 5)
    private var hero: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            BookCoverView(urlString: book.coverRemoteURL)
                .frame(width: 76, height: 102)
                .clipShape(.rect(cornerRadius: 5, style: .continuous))
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(book.displayTitle)
                        .font(.system(size: 16))
                        .foregroundStyle(PassagePalette.ink)
                        .lineLimit(2)
                    if !book.author.isEmpty {
                        Text(book.author)
                            .font(.system(size: 12))
                            .foregroundStyle(PassagePalette.inkMuted)
                            .lineLimit(1)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(journeys.isEmpty ? "아직 기록 없음" : totalDuration.readableDuration)
                        .font(.system(size: 24, weight: .medium).monospacedDigit())
                        .foregroundStyle(PassagePalette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    if let percent = journey.progressPercent {
                        Text("독서 진행률 \(percent)%")
                            .font(.system(size: 12))
                            .foregroundStyle(PassagePalette.inkMuted)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 2)
        }
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
                // 목업은 장소별 집계지만 여기서는 **세션 단위를 유지**한다 — 장소로 묶으면
                // 개별 기억 상세로 들어가는 유일한 경로가 끊긴다. 행 형식만 차용했다. (→ #27)
                VStack(spacing: 0) {
                    ForEach(Array(journeys.enumerated()), id: \.element.id) { index, session in
                        NavigationLink(value: session) {
                            journeyRow(index: index, session: session)
                        }
                        .buttonStyle(.plain)
                        if session.id != journeys.last?.id {
                            Divider().overlay(PassagePalette.hairline)
                        }
                    }
                }
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

    /// `1. 집 근처 카페 ──────── 35분` — 순번은 여정의 순서(오래된 것부터).
    private func journeyRow(index: Int, session: ReadingSession) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Text("\(index + 1).")
                .font(.system(size: 14).monospacedDigit())
                .foregroundStyle(PassagePalette.inkMuted)
            Text(session.place?.name.isEmpty == false ? session.place!.name : "장소 없음")
                .font(.system(size: 16))
                .foregroundStyle(PassagePalette.ink)
                .lineLimit(1)
            Spacer(minLength: Theme.Spacing.sm)
            Text(session.duration.readableDuration)
                .font(.system(size: 16).monospacedDigit())
                .foregroundStyle(PassagePalette.ink)
                .lineLimit(1)
        }
        .padding(.vertical, Theme.Spacing.sm)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(index + 1)번째 여정, \(session.place?.name ?? "장소 없음"), \(session.duration.readableDuration)")
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
