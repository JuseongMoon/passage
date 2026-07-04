//
//  Quote.swift
//  passage
//
//  책에서 마음에 남은 구절(인용구/하이라이트). 독서 기억을 풍부하게. (Memory over Productivity)
//

import Foundation
import SwiftData

// nonisolated: SwiftData 내부 스레드 접근 허용(→ Book.swift 주석 참고).
@Model
nonisolated final class Quote {
    var id: UUID = UUID()
    var text: String = ""
    var page: Int?
    var dateCreated: Date = Date()

    var book: Book?

    init(text: String = "", page: Int? = nil, book: Book? = nil) {
        self.text = text
        self.page = page
        self.book = book
    }
}
