//
//  ReadingSessionTests.swift
//  passageTests
//
//  활성 세션 시작/종료/취소/복원 로직 검증. (Session is Source of Truth)
//  주의: 컨테이너를 로컬로 보유한 채 사용한다.
//

import Testing
import SwiftData
import Foundation
@testable import passage

@MainActor
struct ReadingSessionTests {

    @Test func startInsertsAndActivatesSession() throws {
        let container = PassageModelContainer.makePreview()
        let controller = ReadingSessionController(modelContext: container.mainContext)
        let book = Book(title: "데미안")
        container.mainContext.insert(book)

        controller.start(book: book)

        #expect(controller.isReading)
        #expect(controller.activeSession?.book?.title == "데미안")
        let all = try container.mainContext.fetch(FetchDescriptor<ReadingSession>())
        #expect(all.count == 1)
        #expect(all.first?.endDate == nil)
    }

    @Test func stopFinalizesSession() throws {
        let container = PassageModelContainer.makePreview()
        let controller = ReadingSessionController(modelContext: container.mainContext)
        let book = Book(title: "데미안")
        container.mainContext.insert(book)

        controller.start(book: book)
        controller.stop(endPage: 42)

        #expect(!controller.isReading)
        let all = try container.mainContext.fetch(FetchDescriptor<ReadingSession>())
        #expect(all.count == 1)
        #expect(all.first?.endDate != nil)
        #expect(all.first?.endPage == 42)
        #expect((all.first?.duration ?? -1) >= 0)
    }

    @Test func cancelDiscardsSession() throws {
        let container = PassageModelContainer.makePreview()
        let controller = ReadingSessionController(modelContext: container.mainContext)
        let book = Book(title: "데미안")
        container.mainContext.insert(book)

        controller.start(book: book)
        controller.cancel()

        #expect(!controller.isReading)
        let all = try container.mainContext.fetch(FetchDescriptor<ReadingSession>())
        #expect(all.isEmpty)
    }

    @Test func restoresActiveSessionOnInit() throws {
        let container = PassageModelContainer.makePreview()
        let context = container.mainContext
        context.insert(ReadingSession())   // endDate nil == 진행 중

        let controller = ReadingSessionController(modelContext: context)

        #expect(controller.isReading)
        #expect(controller.activeSession != nil)
    }

    @Test func sessionNotePersists() throws {
        let container = PassageModelContainer.makePreview()
        let context = container.mainContext
        let session = ReadingSession()
        context.insert(session)

        session.note = "이 장면이 오래 남았다"
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<ReadingSession>())
        #expect(fetched.first?.note == "이 장면이 오래 남았다")
    }
}
