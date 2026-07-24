//
//  ReadingSessionControllerTests.swift
//  passageTests
//
//  세션 흐름 상태머신(준비→진행/일시정지→종료→장소) + 일시정지 경과 누적 + 취소 시맨틱 검증.
//

import Testing
import SwiftData
import Foundation
@testable import passage

@MainActor
struct ReadingSessionControllerTests {

    private func makeContext() -> (ModelContainer, ModelContext) {
        let container = PassageModelContainer.makePreview()
        return (container, container.mainContext)   // 컨테이너를 함께 반환해 보유 유지
    }

    @Test func beginThenConfirmStartsRunningAndSaves() throws {
        let (container, ctx) = makeContext()
        let book = Book(title: "책")
        ctx.insert(book)
        let controller = ReadingSessionController(modelContext: ctx)

        controller.beginReading(book: book)
        #expect(controller.phase == .ready)
        #expect(controller.pendingBook != nil)

        controller.confirmStart(startPage: 12)
        #expect(controller.phase == .running)
        #expect(controller.isReading)
        #expect(controller.activeSession?.startPage == 12)

        // 즉시 저장되어 조회 가능해야 한다.
        let saved = try ctx.fetch(FetchDescriptor<ReadingSession>())
        #expect(saved.count == 1)
        _ = container
    }

    @Test func pauseFreezesElapsedResumeContinues() {
        let (container, ctx) = makeContext()
        let book = Book(title: "책")
        ctx.insert(book)
        let controller = ReadingSessionController(modelContext: ctx)
        controller.beginReading(book: book)
        controller.confirmStart(startPage: nil)

        // 진행 중: 미래 시각으로 물으면 경과가 늘어난다.
        let running = controller.elapsed(now: Date().addingTimeInterval(100))
        #expect(running >= 99 && running <= 102)

        controller.pause()
        #expect(controller.phase == .paused)
        #expect(controller.isPaused)
        // 일시정지: 미래 시각으로 물어도 경과가 늘지 않는다(누적분만).
        let paused = controller.elapsed(now: Date().addingTimeInterval(1000))
        #expect(paused < 2)

        controller.resume()
        #expect(controller.phase == .running)
        #expect(!controller.isPaused)
        _ = container
    }

    @Test func endMovesToEndedAndFinalizes() {
        let (container, ctx) = makeContext()
        let book = Book(title: "책")
        ctx.insert(book)
        let controller = ReadingSessionController(modelContext: ctx)
        controller.beginReading(book: book)
        controller.confirmStart(startPage: 10)

        controller.endReading()
        #expect(controller.phase == .ended)
        #expect(controller.activeSession == nil)
        #expect(controller.endedSession?.endDate != nil)
        #expect((controller.endedSession?.duration ?? 0) >= 0)
        _ = container
    }

    @Test func finishEndedInlineSetsPagesWithoutPlace() throws {
        let (container, ctx) = makeContext()
        let book = Book(title: "책")
        ctx.insert(book)
        let controller = ReadingSessionController(modelContext: ctx)
        controller.beginReading(book: book)
        controller.confirmStart(startPage: 10)
        controller.endReading()

        controller.finishEndedInline(startPage: 10, endPage: 42, placeName: nil)
        #expect(controller.phase == nil)
        #expect(controller.endedSession == nil)
        let session = try #require(try ctx.fetch(FetchDescriptor<ReadingSession>()).first)
        #expect(session.startPage == 10)
        #expect(session.endPage == 42)
        #expect(session.place == nil)          // 장소 없이 저장(장소는 선택)
        _ = container
    }

    @Test func finishEndedInlineAssignsPlaceAndClosesWithoutPrompt() throws {
        let (container, ctx) = makeContext()
        let book = Book(title: "책")
        ctx.insert(book)
        let controller = ReadingSessionController(modelContext: ctx)
        controller.beginReading(book: book)
        controller.confirmStart(startPage: 10)
        controller.endReading()

        controller.finishEndedInline(startPage: 10, endPage: 40, placeName: "동네 카페",
                                     latitude: 37.5, longitude: 127.0, address: "서울")
        #expect(controller.phase == nil)
        #expect(controller.endedSession == nil)   // 별도 장소 화면 없이 인라인 저장 후 닫힘
        let sessions = try ctx.fetch(FetchDescriptor<ReadingSession>())
        #expect(sessions.first?.endPage == 40)
        #expect(sessions.first?.place?.name == "동네 카페")
        #expect(try ctx.fetch(FetchDescriptor<Place>()).count == 1)
        _ = container
    }

    @Test func finishEndedInlineEmptyNameSavesNoPlace() throws {
        let (container, ctx) = makeContext()
        let book = Book(title: "책")
        ctx.insert(book)
        let controller = ReadingSessionController(modelContext: ctx)
        controller.beginReading(book: book)
        controller.confirmStart(startPage: nil)
        controller.endReading()

        controller.finishEndedInline(startPage: nil, endPage: nil, placeName: "   ")
        #expect(controller.phase == nil)
        #expect(try ctx.fetch(FetchDescriptor<Place>()).isEmpty)   // 빈 이름 → 장소 생성 안 함
        #expect(try ctx.fetch(FetchDescriptor<ReadingSession>()).first?.place == nil)
        _ = container
    }

    @Test func cancelFromRunningDiscardsSession() throws {
        let (container, ctx) = makeContext()
        let book = Book(title: "책")
        ctx.insert(book)
        let controller = ReadingSessionController(modelContext: ctx)
        controller.beginReading(book: book)
        controller.confirmStart(startPage: nil)

        controller.cancelReading()
        #expect(controller.phase == nil)
        let sessions = try ctx.fetch(FetchDescriptor<ReadingSession>())
        #expect(sessions.isEmpty)          // 진행 중 세션은 폐기
        _ = container
    }

    @Test func cancelFromEndedKeepsSavedSession() throws {
        let (container, ctx) = makeContext()
        let book = Book(title: "책")
        ctx.insert(book)
        let controller = ReadingSessionController(modelContext: ctx)
        controller.beginReading(book: book)
        controller.confirmStart(startPage: nil)
        controller.endReading()            // 이미 확정 저장됨

        controller.cancelReading()
        #expect(controller.phase == nil)
        let sessions = try ctx.fetch(FetchDescriptor<ReadingSession>())
        #expect(sessions.count == 1)       // 종료된 세션은 유지
        _ = container
    }

    @Test func suggestedStartPageFromLastEndPage() {
        let (container, ctx) = makeContext()
        let book = Book(title: "책")
        ctx.insert(book)
        let prev = ReadingSession(book: book, startPage: 0)
        prev.endPage = 88
        prev.endDate = Date()
        ctx.insert(prev)
        let controller = ReadingSessionController(modelContext: ctx)

        #expect(controller.suggestedStartPage(for: book) == 88)
        _ = container
    }
}
