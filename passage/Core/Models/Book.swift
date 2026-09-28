//
//  Book.swift
//  passage
//
//  읽는 대상. 검색 · ISBN · 수동 등록으로 추가된다.
//  참조 엔티티이며, 실제 독서 기록은 ReadingSession이 가진다. (Session is Source of Truth)
//  저장 속성·관계는 스키마 스냅샷에 있고 여기엔 동작만 둔다. (→ Schema/PassageSchema.swift)
//

import Foundation
import SwiftData

// nonisolated: 모델 동작도 SwiftData 내부 스레드에서 불릴 수 있다(→ Schema/PassageSchemaV1.swift 주석).
nonisolated extension Book {
    convenience init(
        title: String = "",
        author: String = "",
        isbn: String? = nil,
        totalPageCount: Int? = nil,
        coverRemoteURL: String? = nil
    ) {
        self.init()
        // 제목의 괄호 이후는 부제로 분리해 따로 보관하고, 본문 제목엔 괄호 앞부분만 남긴다.
        let parsed = Self.parseTitle(title)
        self.title = parsed.title
        self.subtitle = parsed.subtitle
        self.author = author
        self.isbn = isbn
        self.totalPageCount = totalPageCount
        self.coverRemoteURL = coverRemoteURL
    }

    /// 완독 여부(다 읽음 표시가 있으면 true). 독서여정 필터의 진행 중/완료 구분 기준.
    var isFinished: Bool { finishedDate != nil }

    // MARK: 제목 · 부제 파싱

    /// 원제목을 본문 제목과 괄호 부제로 나눈다. 첫 여는 괄호('(' 또는 전각 '（') 이후를 부제로 보고
    /// 괄호를 떼어낸다. 괄호가 없으면 부제는 "". 제목이 괄호로 시작하면(본문이 비면) 분리하지 않는다.
    static func parseTitle(_ raw: String) -> (title: String, subtitle: String) {
        let opens: Set<Character> = ["(", "（"]
        guard let openIdx = raw.firstIndex(where: { opens.contains($0) }) else {
            return (raw.trimmingCharacters(in: .whitespacesAndNewlines), "")
        }
        let mainPart = raw[..<openIdx].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !mainPart.isEmpty else {
            return (raw.trimmingCharacters(in: .whitespacesAndNewlines), "")
        }
        var subPart = raw[raw.index(after: openIdx)...]
        if let last = subPart.last, last == ")" || last == "）" {
            subPart = subPart.dropLast()
        }
        return (mainPart, subPart.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// 표시용 제목 — 저장 제목이 (기존 데이터·타기기 동기화로) 아직 괄호를 품고 있어도 항상 괄호 앞부분만 보인다.
    var displayTitle: String { Self.parseTitle(title).title }

    /// 기존/동기화된 책의 제목을 본문+부제로 정규화한다(멱등). 서재 진입 시 호출.
    @MainActor
    static func normalizeTitles(in context: ModelContext) {
        guard let books = try? context.fetch(FetchDescriptor<Book>()) else { return }
        var changed = false
        for book in books {
            let parsed = parseTitle(book.title)
            guard parsed.title != book.title else { continue }   // 분리 필요 없으면 건너뜀
            book.title = parsed.title
            if book.subtitle.isEmpty { book.subtitle = parsed.subtitle }
            changed = true
        }
        if changed { try? context.save() }
    }
}
