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

    @Test func assignPlaceLinksSession() throws {
        let container = PassageModelContainer.makePreview()
        let context = container.mainContext
        let controller = ReadingSessionController(modelContext: context)
        let book = Book(title: "데미안")
        context.insert(book)

        controller.beginReading(book: book)
        controller.confirmStart(startPage: nil)
        controller.endReading()
        controller.finishEndedInline(startPage: nil, endPage: nil, placeName: nil)

        let session = try #require(try context.fetch(FetchDescriptor<ReadingSession>()).first)
        let place = Place(name: "동네 카페")
        context.insert(place)
        controller.assignPlace(place, to: session)   // 독서여정에서 장소를 나중에 연결

        #expect(session.place?.name == "동네 카페")
    }

    @Test func finishEndedInlineWithoutPlaceKeepsSession() throws {
        let container = PassageModelContainer.makePreview()
        let context = container.mainContext
        let controller = ReadingSessionController(modelContext: context)
        let book = Book(title: "데미안")
        context.insert(book)

        controller.beginReading(book: book)
        controller.confirmStart(startPage: nil)
        controller.endReading()
        controller.finishEndedInline(startPage: nil, endPage: nil, placeName: nil)

        let session = try #require(try context.fetch(FetchDescriptor<ReadingSession>()).first)
        #expect(session.place == nil)     // 장소는 선택 — 없이도 저장
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

    @Test func placePhotoPersistsAndCascades() throws {
        let container = PassageModelContainer.makePreview()
        let context = container.mainContext
        let place = Place(name: "카페")
        context.insert(place)
        let data = Data([0x01, 0x02, 0x03])
        context.insert(PlacePhoto(data: data, place: place))
        try context.save()

        let photos = try context.fetch(FetchDescriptor<PlacePhoto>())
        #expect(photos.count == 1)
        #expect(photos.first?.data == data)
        #expect(photos.first?.place?.name == "카페")

        context.delete(place)          // 장소 삭제 시 사진도 cascade 삭제
        try context.save()
        #expect(try context.fetch(FetchDescriptor<PlacePhoto>()).isEmpty)
    }
}
