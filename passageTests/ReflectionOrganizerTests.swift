//
//  ReflectionOrganizerTests.swift
//  passageTests
//
//  연도별 회고 집계 검증: 완료 세션만·중복 제거·연도별 구절 분리.
//

import Testing
import SwiftData
import Foundation
@testable import passage

@MainActor
struct ReflectionOrganizerTests {

    private func date(_ y: Int, _ m: Int, _ d: Int, _ cal: Calendar) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d))!
    }

    @Test func aggregatesByYear() throws {
        let container = PassageModelContainer.makePreview()
        let ctx = container.mainContext
        let cal = Calendar(identifier: .gregorian)

        let book2026 = Book(title: "2026책"); ctx.insert(book2026)
        let book2025 = Book(title: "2025책"); ctx.insert(book2025)
        let place = Place(name: "카페"); ctx.insert(place)

        let s1 = ReadingSession(book: book2026, startDate: date(2026, 3, 1, cal))
        s1.endDate = date(2026, 3, 1, cal); s1.place = place; ctx.insert(s1)

        let s2 = ReadingSession(book: book2025, startDate: date(2025, 6, 1, cal))
        s2.endDate = date(2025, 6, 1, cal); ctx.insert(s2)

        // 진행 중(endDate nil) — 집계에서 제외
        let s3 = ReadingSession(book: book2026, startDate: date(2026, 5, 1, cal))
        ctx.insert(s3)

        let quote = Quote(text: "구절", book: book2026)
        quote.dateCreated = date(2026, 4, 1, cal)
        ctx.insert(quote)
        try ctx.save()

        let sessions = try ctx.fetch(FetchDescriptor<ReadingSession>())
        let quotes = try ctx.fetch(FetchDescriptor<Quote>())

        #expect(ReflectionOrganizer.availableYears(sessions, calendar: cal) == [2026, 2025])

        let d2026 = ReflectionOrganizer.digest(year: 2026, sessions: sessions, quotes: quotes, calendar: cal)
        #expect(d2026.books.map(\.title) == ["2026책"])   // 진행 중 세션 제외·중복 없음
        #expect(d2026.places.count == 1)
        #expect(d2026.quotes.count == 1)

        let d2025 = ReflectionOrganizer.digest(year: 2025, sessions: sessions, quotes: quotes, calendar: cal)
        #expect(d2025.books.map(\.title) == ["2025책"])
        #expect(d2025.quotes.isEmpty)                     // 2026 구절은 분리
    }
}
