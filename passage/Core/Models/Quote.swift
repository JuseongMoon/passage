//
//  Quote.swift
//  passage
//
//  책에서 마음에 남은 구절(인용구/하이라이트). 독서 기억을 풍부하게. (Memory over Productivity)
//  저장 속성·관계는 스키마 스냅샷에 있고 여기엔 동작만 둔다. (→ Schema/PassageSchema.swift)
//

import Foundation
import SwiftData

// nonisolated: 모델 동작도 SwiftData 내부 스레드에서 불릴 수 있다(→ Schema/PassageSchemaV1.swift 주석).
nonisolated extension Quote {
    convenience init(text: String = "", page: Int? = nil, book: Book? = nil) {
        self.init()
        self.text = text
        self.page = page
        self.book = book
    }
}
