//
//  ReadingSessionController.swift
//  passage
//
//  독서 세션 흐름(준비→진행/일시정지→종료→장소)을 관장한다. (Session is Source of Truth)
//  세션은 "시작"(confirmStart) 즉시 저장되어 앱 종료·크래시에도 유지되고, 다음 실행 시 복원된다.
//  일시정지 지원을 위해 경과시간을 누적한다(누적값은 메모리 보관 — 종료 시 duration으로 확정 저장).
//

import Foundation
import SwiftData
import Observation

@MainActor
@Observable
final class ReadingSessionController {
    private let modelContext: ModelContext

    /// 준비(ready) 단계의 책 — 아직 세션은 만들지 않았다.
    private(set) var pendingBook: Book?

    /// 진행 중(running/paused) 세션. endDate == nil.
    private(set) var activeSession: ReadingSession?

    /// 종료 후 페이지 입력 대기(ended) 세션. endDate는 이미 확정됐다.
    private(set) var endedSession: ReadingSession?

    /// "어디서 읽으셨나요?" 장소 질문 대기 세션(기존 장소 화면).
    private(set) var sessionAwaitingPlace: ReadingSession?

    /// 일시정지 여부.
    private(set) var isPaused = false

    // 경과시간 누적(일시정지 구간 제외). 타이머 표시는 TimelineView가 구동하므로 관찰 대상에서 제외.
    @ObservationIgnored private var accumulatedElapsed: TimeInterval = 0
    @ObservationIgnored private var runningSince: Date?

    /// 세션 오버레이가 떠 있어야 하는 단계.
    enum Phase { case ready, running, paused, ended }
    var phase: Phase? {
        if pendingBook != nil { return .ready }
        if activeSession != nil { return isPaused ? .paused : .running }
        if endedSession != nil { return .ended }
        return nil
    }

    /// 세션 흐름(오버레이) 활성 여부 — 장소 질문 단계 포함.
    var isFlowActive: Bool { phase != nil || sessionAwaitingPlace != nil }

    /// 진행 중(running/paused) 세션 존재 여부.
    var isReading: Bool { activeSession != nil }

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        restoreActiveSession()
    }

    /// 지난 세션의 마지막 페이지(시작 페이지 자동 채움 제안).
    func suggestedStartPage(for book: Book) -> Int? {
        (book.sessions ?? [])
            .filter { $0.endDate != nil }
            .compactMap(\.endPage)
            .max()
    }

    /// 준비 단계 진입(시작 페이지를 고를 수 있게).
    func beginReading(book: Book) {
        guard !isFlowActive else { return }
        pendingBook = book
    }

    /// 실제 독서 시작: 세션을 즉시 저장하고 타이머를 돌린다.
    func confirmStart(startPage: Int?) {
        guard let book = pendingBook else { return }
        let session = ReadingSession(book: book, startPage: startPage)
        modelContext.insert(session)
        try? modelContext.save()      // 즉시 저장 → 앱 종료·크래시에도 유지
        pendingBook = nil
        accumulatedElapsed = 0
        runningSince = Date()
        isPaused = false
        activeSession = session
    }

    /// 현재까지 경과시간(일시정지 구간 제외).
    func elapsed(now: Date = Date()) -> TimeInterval {
        accumulatedElapsed + (runningSince.map { max(0, now.timeIntervalSince($0)) } ?? 0)
    }

    func pause() {
        guard activeSession != nil, !isPaused, let since = runningSince else { return }
        accumulatedElapsed += max(0, Date().timeIntervalSince(since))
        runningSince = nil
        isPaused = true
    }

    func resume() {
        guard activeSession != nil, isPaused else { return }
        runningSince = Date()
        isPaused = false
    }

    /// 독서 종료: endDate·duration을 확정 저장하고 페이지 입력(ended) 단계로.
    func endReading() {
        guard let session = activeSession else { return }
        session.endDate = Date()
        session.duration = elapsed()
        try? modelContext.save()
        runningSince = nil
        isPaused = false
        activeSession = nil
        endedSession = session
    }

    /// ended 단계 저장: endPage 확정 후 "어디서 읽으셨나요?"(기존 장소 화면)로 넘긴다.
    func finishEnded(startPage: Int?, endPage: Int?) {
        guard let session = endedSession else { return }
        session.startPage = startPage
        session.endPage = endPage
        try? modelContext.save()
        endedSession = nil
        sessionAwaitingPlace = session
    }

    /// 종료된 세션에 장소를 연결하고 질문을 닫는다.
    func assignPlace(_ place: Place, to session: ReadingSession) {
        session.place = place
        try? modelContext.save()
        sessionAwaitingPlace = nil
    }

    /// 장소 질문 건너뛰기(장소는 선택 — 세션은 그대로 저장된 채 닫힘).
    func skipPlacePrompt() {
        sessionAwaitingPlace = nil
    }

    /// 오버레이 닫기/취소. 진행 중(ready/running/paused) 세션은 폐기, 이미 종료된 세션은 저장된 채 닫는다.
    func cancelReading() {
        if let session = activeSession {          // 진행 중 세션은 폐기
            modelContext.delete(session)
            try? modelContext.save()
        }
        // endedSession은 endReading에서 이미 확정 저장됨 → 삭제하지 않고 닫기만 한다.
        pendingBook = nil
        activeSession = nil
        endedSession = nil
        runningSince = nil
        isPaused = false
        accumulatedElapsed = 0
    }

    /// 앱 시작 시 진행 중이던 세션(endDate == nil)을 복원(러닝 상태로 — 일시정지 구간은 미보존).
    private func restoreActiveSession() {
        var descriptor = FetchDescriptor<ReadingSession>(
            predicate: #Predicate { $0.endDate == nil }
        )
        descriptor.fetchLimit = 1
        if let session = try? modelContext.fetch(descriptor).first {
            activeSession = session
            accumulatedElapsed = 0
            runningSince = session.startDate      // 경과 = now - startDate
            isPaused = false
        }
    }
}
