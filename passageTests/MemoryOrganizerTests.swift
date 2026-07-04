//
//  MemoryOrganizerTests.swift
//  passageTests
//
//  저널 렌즈(책/장소) 그룹핑 로직 검증.
//

import Testing
import SwiftData
import Foundation
@testable import passage

@MainActor
struct MemoryOrganizerTests {

    private func addFinished(book: Book?, place: Place?, in context: ModelContext) {
        let session = ReadingSession(book: book)
        session.place = place
        session.endDate = Date()
        session.duration = 600
        context.insert(session)
    }

    @Test func groupsByBook() throws {
        let container = PassageModelContainer.makePreview()
        let context = container.mainContext
        let a = Book(title: "안나 카레니나")
        let b = Book(title: "데미안")
        context.insert(a); context.insert(b)
        addFinished(book: a, place: nil, in: context)
        addFinished(book: a, place: nil, in: context)
        addFinished(book: b, place: nil, in: context)

        let sessions = try context.fetch(FetchDescriptor<ReadingSession>())
        let groups = MemoryOrganizer.grouped(sessions, by: .book)

        #expect(groups.count == 2)
        #expect(groups.first { $0.title == "안나 카레니나" }?.sessions.count == 2)
        #expect(groups.first { $0.title == "데미안" }?.sessions.count == 1)
    }

    @Test func groupsByPlaceIncludingNoPlaceBucket() throws {
        let container = PassageModelContainer.makePreview()
        let context = container.mainContext
        let book = Book(title: "데미안")
        let cafe = Place(name: "동네 카페")
        context.insert(book); context.insert(cafe)
        addFinished(book: book, place: cafe, in: context)
        addFinished(book: book, place: nil, in: context)   // 장소 없음

        let sessions = try context.fetch(FetchDescriptor<ReadingSession>())
        let groups = MemoryOrganizer.grouped(sessions, by: .place)

        #expect(groups.count == 2)
        #expect(groups.contains { $0.title == "동네 카페" })
        #expect(groups.contains { $0.title == "장소 없음" })
    }
}
