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
        self.title = title
        self.author = author
        self.isbn = isbn
        self.totalPageCount = totalPageCount
        self.coverRemoteURL = coverRemoteURL
    }

    /// 완독 여부(다 읽음 표시가 있으면 true). 독서여정 필터의 진행 중/완료 구분 기준.
    var isFinished: Bool { finishedDate != nil }
}
