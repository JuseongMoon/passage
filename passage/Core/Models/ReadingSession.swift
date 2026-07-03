//
//  ReadingSession.swift
//  passage
//
//  한 번의 독서 행위. 앱의 원자 단위이자 Source of Truth.
//  시작 즉시 저장되며(endDate == nil == 진행 중), 종료 시 duration을 확정한다.
//

import Foundation
import SwiftData

// nonisolated: SwiftData 내부 스레드 접근 허용(→ Book.swift 주석 참고).
@Model
nonisolated final class ReadingSession {
    var id: UUID = UUID()
    var startDate: Date = Date()
    var endDate: Date?                  // nil == 진행 중
    var duration: TimeInterval = 0      // 종료 시 확정(일시정지 등 확장 대비해 계산값을 저장)
    var startPage: Int?
    var endPage: Int?
    var note: String?                   // (Phase 2) 세션 회고 한 줄

    // to-one 관계(inverse는 Book/Place 쪽 to-many에서 선언).
    var book: Book?
    var place: Place?

    /// 진행 중 여부(파생값, 미저장).
    var isActive: Bool { endDate == nil }

    init(book: Book? = nil, startDate: Date = Date(), startPage: Int? = nil) {
        self.book = book
        self.startDate = startDate
        self.startPage = startPage
    }
}
