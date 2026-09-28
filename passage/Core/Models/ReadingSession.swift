//
//  ReadingSession.swift
//  passage
//
//  한 번의 독서 행위. 앱의 원자 단위이자 Source of Truth.
//  시작 즉시 저장되며(endDate == nil == 진행 중), 종료 시 duration을 확정한다.
//  저장 속성·관계는 스키마 스냅샷에 있고 여기엔 동작만 둔다. (→ Schema/PassageSchema.swift)
//

import Foundation
import SwiftData

// nonisolated: 모델 동작도 SwiftData 내부 스레드에서 불릴 수 있다(→ Schema/PassageSchemaV1.swift 주석).
nonisolated extension ReadingSession {
    convenience init(book: Book? = nil, startDate: Date = Date(), startPage: Int? = nil) {
        self.init()
        self.book = book
        self.startDate = startDate
        self.startPage = startPage
    }

    /// 진행 중 여부(파생값, 미저장).
    var isActive: Bool { endDate == nil }

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
