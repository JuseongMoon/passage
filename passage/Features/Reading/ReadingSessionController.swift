//
//  ReadingSessionController.swift
//  passage
//
//  활성 독서 세션의 시작/종료/복원을 관장한다. (Session is Source of Truth)
//  세션은 시작 즉시 저장되어 앱 종료·크래시에도 유지되고, 다음 실행 시 복원된다.
//

import Foundation
import SwiftData
import Observation

@MainActor
@Observable
final class ReadingSessionController {
    private let modelContext: ModelContext

    /// 현재 진행 중인 세션(없으면 nil).
    private(set) var activeSession: ReadingSession?

    var isReading: Bool { activeSession != nil }

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        restoreActiveSession()
    }

    /// 독서 시작: 세션을 즉시 저장하고 활성 세션으로 둔다.
    func start(book: Book, startPage: Int? = nil) {
        guard activeSession == nil else { return }
        let session = ReadingSession(book: book, startPage: startPage)
        modelContext.insert(session)
        activeSession = session
    }

    /// 독서 종료: endDate·duration을 확정한다. (장소 질문은 Phase 1c에서 이어붙임)
    func stop(endPage: Int? = nil) {
        guard let session = activeSession else { return }
        let now = Date()
        session.endDate = now
        session.duration = now.timeIntervalSince(session.startDate)
        session.endPage = endPage
        activeSession = nil
    }

    /// 잘못 시작한 세션을 저장하지 않고 폐기.
    func cancel() {
        if let session = activeSession {
            modelContext.delete(session)
        }
        activeSession = nil
    }

    /// 앱 시작 시 진행 중이던 세션(endDate == nil)을 복원.
    private func restoreActiveSession() {
        var descriptor = FetchDescriptor<ReadingSession>(
            predicate: #Predicate { $0.endDate == nil }
        )
        descriptor.fetchLimit = 1
        activeSession = try? modelContext.fetch(descriptor).first
    }
}
