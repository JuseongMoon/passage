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

    /// 사진은 장소가 아니라 세션이 갖는다 — 같은 곳에서 읽은 다른 날과 섞이지 않는다. (→ DECISIONS #27)
    @Test func sessionPhotoPersistsAndCascades() throws {
        let container = PassageModelContainer.makePreview()
        let context = container.mainContext
        let book = Book(title: "채식주의자")
        context.insert(book)
        let session = ReadingSession(book: book)
        context.insert(session)
        let data = Data([0x01, 0x02, 0x03])
        context.insert(SessionPhoto(data: data, session: session))
        try context.save()

        let photos = try context.fetch(FetchDescriptor<SessionPhoto>())
        #expect(photos.count == 1)
        #expect(photos.first?.data == data)
        #expect(photos.first?.session?.book?.title == "채식주의자")

        context.delete(session)        // 세션 삭제 시 사진도 cascade 삭제
        try context.save()
        #expect(try context.fetch(FetchDescriptor<SessionPhoto>()).isEmpty)
    }

    /// 같은 장소를 여러 세션이 공유해도 사진은 각 세션에 남는다(장소 사진이 아니다).
    @Test func photosStayWithTheirOwnSession() throws {
        let container = PassageModelContainer.makePreview()
        let context = container.mainContext
        let place = Place(name: "카페")
        context.insert(place)
        let first = ReadingSession()
        let second = ReadingSession()
        context.insert(first); context.insert(second)
        first.place = place
        second.place = place
        context.insert(SessionPhoto(data: Data([0x0A]), session: first))
        try context.save()

        #expect(first.photos?.count == 1)
        #expect(second.photos?.isEmpty == true)   // 같은 장소지만 사진은 따라오지 않는다
    }
}
