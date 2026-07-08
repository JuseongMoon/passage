//
//  PassPresentationTests.swift
//  passageTests
//
//  서재 "패스" 표시값의 파생 로직 검증(진행률·최근 여정·총시간·색 안정성).
//  Session is Source of Truth — 전부 세션에서 계산된다.
//

import Testing
import SwiftData
import Foundation
@testable import passage

@MainActor
struct PassPresentationTests {

    @discardableResult
    private func finished(
        book: Book,
        start: Int?,
        end: Int?,
        duration: TimeInterval,
        endDate: Date,
        place: Place? = nil,
        in context: ModelContext
    ) -> ReadingSession {
        let session = ReadingSession(book: book, startPage: start)
        session.endPage = end
        session.duration = duration
        session.endDate = endDate
        session.place = place
        context.insert(session)
        return session
    }

    // MARK: 진행률

    @Test func progressFromMaxEndPageOverTotal() throws {
        let container = PassageModelContainer.makePreview()
        let context = container.mainContext
        let book = Book(title: "책", totalPageCount: 200)
        context.insert(book)
        finished(book: book, start: 0, end: 40, duration: 600, endDate: Date(timeIntervalSince1970: 1000), in: context)
        finished(book: book, start: 40, end: 120, duration: 1200, endDate: Date(timeIntervalSince1970: 2000), in: context)
        try context.save()

        let pass = PassPresentation(book: book)
        #expect(pass.progress == 0.6)          // 120 / 200
        #expect(pass.progressPercent == 60)
        #expect(pass.fallbackLine == nil)
    }

    @Test func progressClampsAtOne() throws {
        let container = PassageModelContainer.makePreview()
        let context = container.mainContext
        let book = Book(title: "책", totalPageCount: 100)
        context.insert(book)
        finished(book: book, start: 0, end: 130, duration: 600, endDate: Date(timeIntervalSince1970: 1000), in: context)
        try context.save()

        let pass = PassPresentation(book: book)
        #expect(pass.progress == 1.0)
        #expect(pass.progressPercent == 100)
    }

    @Test func progressNilWhenNoPageCount() throws {
        let container = PassageModelContainer.makePreview()
        let context = container.mainContext
        let book = Book(title: "책")            // totalPageCount == nil
        context.insert(book)
        finished(book: book, start: 0, end: 40, duration: 600, endDate: Date(timeIntervalSince1970: 1000), in: context)
        try context.save()

        let pass = PassPresentation(book: book)
        #expect(pass.progress == nil)
        #expect(pass.progressPercent == nil)
        #expect(pass.fallbackLine == "1번의 여정 · 10분")
    }

    @Test func emptyBookHasNoSessionsFallback() throws {
        let container = PassageModelContainer.makePreview()
        let context = container.mainContext
        let book = Book(title: "책", totalPageCount: 200)
        context.insert(book)
        try context.save()

        let pass = PassPresentation(book: book)
        #expect(pass.progress == nil)
        #expect(pass.fallbackLine == "아직 기록된 세션이 없어요")
        #expect(pass.totalDurationText == "아직 기록 없음")
        #expect(pass.headerDate == "아직 기록 없음")
        #expect(pass.recentJourneys.isEmpty)
    }

    // MARK: 총 독서시간 (활성 세션 제외)

    @Test func totalDurationSumsOnlyFinished() throws {
        let container = PassageModelContainer.makePreview()
        let context = container.mainContext
        let book = Book(title: "책")
        context.insert(book)
        finished(book: book, start: 0, end: 40, duration: 600, endDate: Date(timeIntervalSince1970: 1000), in: context)
        finished(book: book, start: 40, end: 90, duration: 1200, endDate: Date(timeIntervalSince1970: 2000), in: context)
        // 진행 중(endDate == nil) — 합계에서 제외되어야 한다.
        let active = ReadingSession(book: book, startPage: 90)
        context.insert(active)
        try context.save()

        let pass = PassPresentation(book: book)
        #expect(pass.totalDuration == 1800)
        #expect(pass.sessionCount == 2)
    }

    // MARK: 최근 여정기록

    @Test func recentJourneysMostRecentFirstMaxTwo() throws {
        let container = PassageModelContainer.makePreview()
        let context = container.mainContext
        let book = Book(title: "책")
        let cafe = Place(name: "동네 카페")
        let home = Place(name: "집")
        context.insert(book); context.insert(cafe); context.insert(home)
        finished(book: book, start: 0, end: 10, duration: 300, endDate: Date(timeIntervalSince1970: 1000), place: home, in: context)
        finished(book: book, start: 10, end: 30, duration: 600, endDate: Date(timeIntervalSince1970: 2000), place: cafe, in: context)
        finished(book: book, start: 30, end: 55, duration: 900, endDate: Date(timeIntervalSince1970: 3000), place: home, in: context)
        try context.save()

        let pass = PassPresentation(book: book)
        #expect(pass.recentJourneys.count == 2)                 // 최대 2개
        #expect(pass.recentJourneys[0].place == "집")            // 가장 최근(3000)
        #expect(pass.recentJourneys[1].place == "동네 카페")      // 그 다음(2000)
        #expect(pass.recentJourneys[0].meta == "15분 · 25p")    // 900초=15분, 55-30=25p
    }

    @Test func journeyMetaOmitsPagesWhenMissing() throws {
        let container = PassageModelContainer.makePreview()
        let context = container.mainContext
        let book = Book(title: "책")
        context.insert(book)
        finished(book: book, start: nil, end: nil, duration: 300, endDate: Date(timeIntervalSince1970: 1000), in: context)
        try context.save()

        let pass = PassPresentation(book: book)
        #expect(pass.recentJourneys.first?.meta == "5분")       // 페이지 없으면 시간만
        #expect(pass.recentJourneys.first?.place == "장소 없음")   // 장소 없으면 폴백
    }

    @Test func headerDateKoreanFormat() throws {
        let container = PassageModelContainer.makePreview()
        let context = container.mainContext
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let date = calendar.date(from: DateComponents(year: 2026, month: 6, day: 22))!
        let book = Book(title: "책")
        context.insert(book)
        finished(book: book, start: 0, end: 10, duration: 300, endDate: date, in: context)
        try context.save()

        let pass = PassPresentation(book: book, calendar: calendar)
        #expect(pass.headerDate.hasPrefix("6월 22일 ("))
        #expect(pass.headerDate.hasSuffix(")"))
    }

    // MARK: 색 배정 안정성

    @Test func swatchIndexIsDeterministicAndInRange() {
        let id = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let first = PassagePalette.swatchIndex(for: id)
        let second = PassagePalette.swatchIndex(for: id)
        #expect(first == second)                                        // 재계산 시 동일
        #expect((0..<PassagePalette.swatches.count).contains(first))    // 범위 내
    }

    @Test func swatchForBookMatchesIndex() {
        let book = Book(title: "책")
        let expected = PassagePalette.swatches[PassagePalette.swatchIndex(for: book.id)]
        #expect(PassagePalette.swatch(for: book) == expected)
    }
}
