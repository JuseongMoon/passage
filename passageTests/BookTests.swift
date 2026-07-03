//
//  BookTests.swift
//  passageTests
//
//  Book 데이터 흐름 및 책별 통계(세션 파생) 검증.
//  주의: SwiftData의 mainContext는 컨테이너를 강하게 보유하지 않는다.
//        반드시 컨테이너를 로컬로 보유한 채 context를 사용한다.
//

import Testing
import SwiftData
import Foundation
@testable import passage

@MainActor
struct BookTests {

    /// 책을 넣고 다시 조회하면 그대로 나온다.
    @Test func insertAndFetchBook() throws {
        let container = PassageModelContainer.makePreview()   // 반드시 보유
        let context = container.mainContext
        context.insert(Book(title: "안나 카레니나", author: "톨스토이"))

        let books = try context.fetch(FetchDescriptor<Book>())
        #expect(books.count == 1)
        #expect(books.first?.title == "안나 카레니나")
        #expect(books.first?.author == "톨스토이")
    }

    /// 책별 총 독서시간은 종료된 세션의 duration 합이다.
    @Test func totalDurationSumsCompletedSessions() throws {
        let container = PassageModelContainer.makePreview()   // 반드시 보유
        let context = container.mainContext

        let book = Book(title: "데미안")
        context.insert(book)

        let finished = ReadingSession(book: book)
        finished.endDate = Date()
        finished.duration = 1800   // 30분
        context.insert(finished)

        let ongoing = ReadingSession(book: book)   // 진행 중(endDate nil)
        context.insert(ongoing)

        let completed = try context.fetch(FetchDescriptor<ReadingSession>())
            .filter { $0.endDate != nil }
        #expect(completed.count == 1)
        #expect(completed.reduce(0) { $0 + $1.duration } == 1800)
        #expect(completed.first?.book?.title == "데미안")
    }
}
