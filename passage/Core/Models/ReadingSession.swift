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

    // 이 세션에서 남긴 사진. externalStorage(→ CloudKit CKAsset 자동 동기화). 세션 삭제 시 함께 삭제.
    @Relationship(deleteRule: .cascade, inverse: \SessionPhoto.session)
    var photos: [SessionPhoto]? = []

    /// 진행 중 여부(파생값, 미저장).
    var isActive: Bool { endDate == nil }

    init(book: Book? = nil, startDate: Date = Date(), startPage: Int? = nil) {
        self.book = book
        self.startDate = startDate
        self.startPage = startPage
    }

    // MARK: 페이지 정규화

    /// 저장된 페이지 값을 `PageRules`에 맞춰 강제 교정한다(세션 + 인용구). 멱등 — 매번 호출해도 안전하다.
    /// 검증 없이 저장되던 시절의 값(전체 500쪽인데 999쪽 등)이 남아 있으면 `PageSlider`가 다룰 수 없는
    /// 범위가 되므로, 슬라이더가 그려지기 전에 반드시 한 번 지나가야 한다. (→ Book.normalizeTitles와 같은 자리)
    /// CloudKit으로 뒤늦게 들어오는 타 기기 데이터도 같은 방식으로 걸러진다.
    @MainActor
    static func normalizePages(in context: ModelContext) {
        var changed = false

        // 상한의 권위인 전체 페이지 수부터 정리한다(0·음수로 저장된 값 → 모름).
        if let books = try? context.fetch(FetchDescriptor<Book>()) {
            for book in books {
                let total = PageRules.normalizedTotal(book.totalPageCount)
                guard book.totalPageCount != total else { continue }
                book.totalPageCount = total
                changed = true
            }
        }

        // 세션의 시작·끝 페이지 — 상한 초과는 잘라내고, 역전은 서로 바꾼다.
        if let sessions = try? context.fetch(FetchDescriptor<ReadingSession>()) {
            for session in sessions {
                let fixed = PageRules.normalized(
                    start: session.startPage,
                    end: session.endPage,
                    total: session.book?.totalPageCount
                )
                if session.startPage != fixed.start {
                    session.startPage = fixed.start
                    changed = true
                }
                if session.endPage != fixed.end {
                    session.endPage = fixed.end
                    changed = true
                }
            }
        }

        // 인용구 페이지도 같은 상한을 따른다.
        if let quotes = try? context.fetch(FetchDescriptor<Quote>()) {
            for quote in quotes {
                let page = PageRules.clamped(quote.page, total: quote.book?.totalPageCount)
                guard quote.page != page else { continue }
                quote.page = page
                changed = true
            }
        }

        if changed { try? context.save() }
    }

    /// 한 책의 페이지 값을 현재 상한에 맞춘다 — 전체 페이지 수가 바뀐 직후에 부른다.
    /// 상한을 낮추면(방금 입력한 값이 더 정확하다고 본다) 기존 기록도 그 아래로 따라 내려온다. 저장은 호출부에서.
    @MainActor
    static func normalizePages(of book: Book) {
        let total = book.totalPageCount
        for session in book.sessions ?? [] {
            let fixed = PageRules.normalized(start: session.startPage, end: session.endPage, total: total)
            session.startPage = fixed.start
            session.endPage = fixed.end
        }
        for quote in book.quotes ?? [] {
            quote.page = PageRules.clamped(quote.page, total: total)
        }
    }
}
