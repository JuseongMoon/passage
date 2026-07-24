//
//  Book.swift
//  passage
//
//  읽는 대상. 검색 · ISBN · 수동 등록으로 추가된다.
//  참조 엔티티이며, 실제 독서 기록은 ReadingSession이 가진다. (Session is Source of Truth)
//

import Foundation
import SwiftData

// nonisolated: 모듈 기본 격리가 MainActor여도 SwiftData가 내부 스레드에서 모델에 접근할 수 있어야 한다.
@Model
nonisolated final class Book {
    // CloudKit 규칙: 모든 저장 속성은 optional 또는 기본값을 가진다. @Attribute(.unique) 금지.
    var id: UUID = UUID()
    var title: String = ""
    /// 제목 괄호 부제 — 검색 제목의 첫 '(' 이후를 부제로 떼어 보관(현재 화면 미표시, 향후 사용). 괄호 없으면 "".
    var subtitle: String = ""
    var author: String = ""
    var isbn: String?
    var totalPageCount: Int?
    var coverRemoteURL: String?        // 검색 API가 준 표지 URL
    var coverImageRef: String?         // 로컬 ImageStore 참조(표지 캐시)
    var coverColorHex: String?         // 표지 대표색 "RRGGBB"(서재 카드색 소스). 미추출/표지없음이면 nil → 해시 폴백.
    var dateAdded: Date = Date()
    var finishedDate: Date?            // 완독 표시(다 읽은 날). nil = 읽는 중.

    // 관계는 optional + inverse 명시. 책 삭제 시 그 책의 세션(기억)도 함께 삭제.
    @Relationship(deleteRule: .cascade, inverse: \ReadingSession.book)
    var sessions: [ReadingSession]? = []

    // 이 책에서 남긴 인용구. 책 삭제 시 함께 삭제.
    @Relationship(deleteRule: .cascade, inverse: \Quote.book)
    var quotes: [Quote]? = []

    init(
        title: String = "",
        author: String = "",
        isbn: String? = nil,
        totalPageCount: Int? = nil,
        coverRemoteURL: String? = nil
    ) {
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
    nonisolated static func parseTitle(_ raw: String) -> (title: String, subtitle: String) {
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
