//
//  BookJourneyTests.swift
//  passageTests
//
//  독서여정 지도 값의 파생 로직 검증(장소별 집계·첫 방문 순서·완독 필터·요약).
//  Session is Source of Truth — 전부 세션에서 계산된다.
//

import Testing
import SwiftData
import Foundation
@testable import passage

@MainActor
struct BookJourneyTests {

    @discardableResult
    private func finished(
        book: Book,
        startDate: Date,
        duration: TimeInterval,
        place: Place? = nil,
        in context: ModelContext
    ) -> ReadingSession {
        let session = ReadingSession(book: book, startDate: startDate)
        session.duration = duration
        session.endDate = startDate.addingTimeInterval(duration)
        session.place = place
        context.insert(session)
        return session
    }

    private func t(_ seconds: TimeInterval) -> Date { Date(timeIntervalSince1970: seconds) }

    // MARK: 장소 집계 · 첫 방문 순서

    @Test func stopsGroupedByPlaceOrderedByFirstVisit() throws {
        let container = PassageModelContainer.makePreview()
        let context = container.mainContext
        let book = Book(title: "책")
        let home = Place(name: "집")
        let cafe = Place(name: "카페")
        context.insert(book); context.insert(home); context.insert(cafe)
        finished(book: book, startDate: t(1000), duration: 600, place: home, in: context)   // 집 첫 방문
        finished(book: book, startDate: t(2000), duration: 600, place: cafe, in: context)   // 카페
        finished(book: book, startDate: t(3000), duration: 900, place: home, in: context)   // 집 재방문
        try context.save()

        let journey = BookJourney(book: book)
        #expect(journey.stops.count == 2)                    // 서로 다른 장소 2곳
        #expect(journey.distinctPlaceCount == 2)
        #expect(journey.stops[0].name == "집")                // 첫 방문 1000
        #expect(journey.stops[1].name == "카페")              // 그 다음 2000
        #expect(journey.stops[0].duration == 1500)           // 600 + 900 합산
        #expect(journey.stops[1].duration == 600)
    }

    @Test func totalDurationSumsOnlyCompleted() throws {
        let container = PassageModelContainer.makePreview()
        let context = container.mainContext
        let book = Book(title: "책")
        context.insert(book)
        finished(book: book, startDate: t(1000), duration: 600, in: context)
        finished(book: book, startDate: t(2000), duration: 1200, in: context)
        let active = ReadingSession(book: book)             // 진행 중(endDate == nil)
        context.insert(active)
        try context.save()

        let journey = BookJourney(book: book)
        #expect(journey.totalDuration == 1800)
        #expect(journey.sessionCount == 2)
    }

    @Test func placelessSessionCountsTimeButNotAStop() throws {
        let container = PassageModelContainer.makePreview()
        let context = container.mainContext
        let book = Book(title: "책")
        context.insert(book)
        finished(book: book, startDate: t(1000), duration: 600, place: nil, in: context)   // 장소 없음
        try context.save()

        let journey = BookJourney(book: book)
        #expect(journey.totalDuration == 600)                // 시간은 총합에 포함
        #expect(journey.stops.isEmpty)                       // 지도 지점은 없음
        #expect(journey.distinctPlaceCount == 0)
    }

    // MARK: 완독 상태

    @Test func isFinishedReflectsFinishedDate() throws {
        let container = PassageModelContainer.makePreview()
        let context = container.mainContext
        let reading = Book(title: "읽는 중")
        let done = Book(title: "다 읽음")
        done.finishedDate = t(5000)
        context.insert(reading); context.insert(done)
        finished(book: reading, startDate: t(1000), duration: 600, in: context)
        finished(book: done, startDate: t(1000), duration: 600, in: context)
        try context.save()

        #expect(BookJourney(book: reading).isFinished == false)
        #expect(BookJourney(book: done).isFinished == true)
    }

    // MARK: 목록 · 필터

    @Test func listExcludesBooksWithoutCompletedSessions() throws {
        let container = PassageModelContainer.makePreview()
        let context = container.mainContext
        let read = Book(title: "읽은 책")
        let fresh = Book(title: "안 읽은 책")             // 완료 세션 없음
        context.insert(read); context.insert(fresh)
        finished(book: read, startDate: t(1000), duration: 600, in: context)
        context.insert(ReadingSession(book: fresh))       // 진행 중만
        try context.save()

        let list = BookJourney.list(from: [read, fresh])
        #expect(list.count == 1)
        #expect(list.first?.title == "읽은 책")
    }

    @Test func filterMatchesByFinishedState() throws {
        let container = PassageModelContainer.makePreview()
        let context = container.mainContext
        let reading = Book(title: "읽는 중")
        let done = Book(title: "다 읽음")
        done.finishedDate = t(5000)
        context.insert(reading); context.insert(done)
        finished(book: reading, startDate: t(1000), duration: 600, in: context)
        finished(book: done, startDate: t(1000), duration: 600, in: context)
        try context.save()

        let list = BookJourney.list(from: [reading, done])
        #expect(JourneyFilter.all.count(in: list) == 2)
        #expect(JourneyFilter.inProgress.count(in: list) == 1)
        #expect(JourneyFilter.finished.count(in: list) == 1)
        #expect(JourneyFilter.finished.matches(list.first { $0.title == "다 읽음" }!) == true)
        #expect(JourneyFilter.inProgress.matches(list.first { $0.title == "읽는 중" }!) == true)
    }

    // MARK: 요약

    @Test func summaryCountsHoursBooksAndDistinctPlaces() throws {
        let container = PassageModelContainer.makePreview()
        let context = container.mainContext
        let a = Book(title: "A"); let b = Book(title: "B")
        let home = Place(name: "집"); let cafe = Place(name: "카페")
        context.insert(a); context.insert(b); context.insert(home); context.insert(cafe)
        // A: 집(1시간) + 카페(0.5시간), B: 집(1시간) → 총 2.5시간, 책 2권, 장소 2곳(집·카페 distinct)
        finished(book: a, startDate: t(1000), duration: 3600, place: home, in: context)
        finished(book: a, startDate: t(9000), duration: 1800, place: cafe, in: context)
        finished(book: b, startDate: t(20000), duration: 3600, place: home, in: context)
        try context.save()

        let summary = JourneySummary(books: [a, b])
        #expect(summary.totalHours == 2)                 // Int(9000 / 3600) = 2
        #expect(summary.bookCount == 2)
        #expect(summary.placeCount == 2)                 // 집·카페(중복 제거)
        #expect(summary.sentence == "2시간 동안 2권의 책을 2곳에서 읽었어요")
    }
}
