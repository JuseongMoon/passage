//
//  PlaceTests.swift
//  passageTests
//
//  장소 연결/건너뛰기 로직 및 로컬 이미지 저장 검증.
//

import Testing
import SwiftData
import Foundation
@testable import passage

@MainActor
struct PlaceTests {

    @Test func assignPlaceLinksSessionAndClosesPrompt() throws {
        let container = PassageModelContainer.makePreview()
        let context = container.mainContext
        let controller = ReadingSessionController(modelContext: context)
        let book = Book(title: "데미안")
        context.insert(book)

        controller.start(book: book)
        controller.stop()
        #expect(controller.sessionAwaitingPlace != nil)

        let place = Place(name: "동네 카페")
        context.insert(place)
        let session = try #require(controller.sessionAwaitingPlace)
        controller.assignPlace(place, to: session)

        #expect(controller.sessionAwaitingPlace == nil)
        #expect(session.place?.name == "동네 카페")
    }

    @Test func skipPlaceKeepsSessionWithoutPlace() throws {
        let container = PassageModelContainer.makePreview()
        let context = container.mainContext
        let controller = ReadingSessionController(modelContext: context)
        let book = Book(title: "데미안")
        context.insert(book)

        controller.start(book: book)
        controller.stop()
        let session = try #require(controller.sessionAwaitingPlace)
        controller.skipPlacePrompt()

        #expect(controller.sessionAwaitingPlace == nil)
        #expect(session.place == nil)
        #expect(session.endDate != nil)   // 세션(기억)은 그대로 저장됨
    }

    @Test func localImageStoreSavesLoadsDeletes() async throws {
        let store = LocalImageStore()
        let data = Data([0x01, 0x02, 0x03, 0x04])

        let ref = try await store.save(data)
        let loaded = try await store.loadData(id: ref)
        #expect(loaded == data)

        try await store.delete(id: ref)
        let afterDelete = try await store.loadData(id: ref)
        #expect(afterDelete == nil)
    }
}
