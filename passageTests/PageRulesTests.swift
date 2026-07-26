//
//  PageRulesTests.swift
//  passageTests
//
//  페이지 규칙(상한·역전·0 이하)과 저장된 값의 강제 교정 검증.
//  전체 페이지 수가 상한의 유일한 권위이고, 페이지는 언제나 그에 종속된다.
//

import Testing
import SwiftData
import Foundation
@testable import passage

@MainActor
struct PageRulesTests {

    // MARK: 순수 규칙

    @Test func unknownPageStaysUnknown() {
        #expect(PageRules.clamped(nil, total: 300) == nil)
    }

    @Test func zeroAndNegativeBecomeUnknown() {
        #expect(PageRules.clamped(0, total: 300) == nil)
        #expect(PageRules.clamped(-5, total: 300) == nil)
        #expect(PageRules.clamped(-5, total: nil) == nil)
    }

    @Test func pageIsCappedByTotal() {
        #expect(PageRules.clamped(999, total: 500) == 500)
        #expect(PageRules.clamped(500, total: 500) == 500)
        #expect(PageRules.clamped(200, total: 500) == 200)
    }

    @Test func withoutTotalThereIsNoCap() {
        #expect(PageRules.clamped(999, total: nil) == 999)
        #expect(PageRules.clamped(999, total: 0) == 999)      // 0쪽 = "모름"
    }

    @Test func totalItselfIsNormalized() {
        #expect(PageRules.normalizedTotal(0) == nil)
        #expect(PageRules.normalizedTotal(-1) == nil)
        #expect(PageRules.normalizedTotal(nil) == nil)
        #expect(PageRules.normalizedTotal(320) == 320)
    }

    @Test func reversedRangeIsSwapped() {
        let fixed = PageRules.normalized(start: 200, end: 88, total: 300)
        #expect(fixed.start == 88)
        #expect(fixed.end == 200)
    }

    @Test func rangeIsCappedBeforeComparing() {
        // 둘 다 상한 위 → 둘 다 상한으로 잘리고, 역전도 사라진다.
        let fixed = PageRules.normalized(start: 900, end: 800, total: 500)
        #expect(fixed.start == 500)
        #expect(fixed.end == 500)
    }

    @Test func halfKnownRangeIsKept() {
        let onlyEnd = PageRules.normalized(start: nil, end: 400, total: 300)
        #expect(onlyEnd.start == nil)
        #expect(onlyEnd.end == 300)

        let onlyStart = PageRules.normalized(start: 40, end: nil, total: 300)
        #expect(onlyStart.start == 40)
        #expect(onlyStart.end == nil)
    }

    // MARK: 저장된 값 강제 교정

    @Test func storedPagesBeyondTotalAreCorrected() throws {
        let container = PassageModelContainer.makePreview()   // 컨테이너를 보유해야 context가 살아 있다
        let context = container.mainContext
        let book = Book(title: "책", totalPageCount: 500)
        context.insert(book)

        let session = ReadingSession(book: book, startPage: 100)
        session.endPage = 999                                  // 검증 없이 저장되던 시절의 값
        session.endDate = Date()
        context.insert(session)

        let quote = Quote(text: "구절", page: 900, book: book)
        context.insert(quote)
        try context.save()

        ReadingSession.normalizePages(in: context)

        #expect(session.endPage == 500)
        #expect(session.startPage == 100)
        #expect(quote.page == 500)
    }

    @Test func storedReversedRangeIsCorrected() throws {
        let container = PassageModelContainer.makePreview()
        let context = container.mainContext
        let book = Book(title: "책", totalPageCount: 300)
        context.insert(book)

        let session = ReadingSession(book: book, startPage: 200)
        session.endPage = 88
        session.endDate = Date()
        context.insert(session)
        try context.save()

        ReadingSession.normalizePages(in: context)

        #expect(session.startPage == 88)
        #expect(session.endPage == 200)
    }

    @Test func zeroPagesAndZeroTotalAreCleared() throws {
        let container = PassageModelContainer.makePreview()
        let context = container.mainContext
        let book = Book(title: "책", totalPageCount: 0)        // 0쪽으로 저장돼 있던 책
        context.insert(book)

        let session = ReadingSession(book: book, startPage: 0)
        session.endPage = 120
        session.endDate = Date()
        context.insert(session)
        try context.save()

        ReadingSession.normalizePages(in: context)

        #expect(book.totalPageCount == nil)                    // 0 → 모름
        #expect(session.startPage == nil)                      // 0 → 미기록
        #expect(session.endPage == 120)                        // 상한이 없으니 그대로
    }

    @Test func normalizationIsIdempotent() throws {
        let container = PassageModelContainer.makePreview()
        let context = container.mainContext
        let book = Book(title: "책", totalPageCount: 400)
        context.insert(book)

        let session = ReadingSession(book: book, startPage: 700)
        session.endPage = 650
        session.endDate = Date()
        context.insert(session)
        try context.save()

        ReadingSession.normalizePages(in: context)
        let firstStart = session.startPage
        let firstEnd = session.endPage

        ReadingSession.normalizePages(in: context)             // 다시 돌려도 값이 흔들리지 않는다
        #expect(session.startPage == firstStart)
        #expect(session.endPage == firstEnd)
        #expect(firstEnd == 400)
    }

    @Test func loweringTotalPullsRecordsDown() throws {
        let container = PassageModelContainer.makePreview()
        let context = container.mainContext
        let book = Book(title: "책", totalPageCount: 500)
        context.insert(book)

        let session = ReadingSession(book: book, startPage: 100)
        session.endPage = 480
        session.endDate = Date()
        context.insert(session)
        try context.save()

        book.totalPageCount = 300                              // 방금 입력한 값이 더 정확하다고 본다
        ReadingSession.normalizePages(of: book)

        #expect(session.endPage == 300)
        #expect(session.startPage == 100)
    }

    // MARK: 진행률과의 정합

    @Test func correctedRecordsYieldSaneProgress() throws {
        let container = PassageModelContainer.makePreview()
        let context = container.mainContext
        let book = Book(title: "책", totalPageCount: 500)
        context.insert(book)

        let session = ReadingSession(book: book, startPage: 100)
        session.endPage = 999
        session.endDate = Date()
        session.duration = 3600
        context.insert(session)
        try context.save()

        ReadingSession.normalizePages(in: context)

        let pass = PassPresentation(book: book)
        #expect(pass.progressPercent == 100)                   // 199%가 아니라 100%
        #expect(pass.progress == 1)
    }
}
