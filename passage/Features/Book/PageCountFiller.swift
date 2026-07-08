//
//  PageCountFiller.swift
//  passage
//
//  책 추가 후 전체 페이지 수가 비어 있으면 ISBN으로 보조 조회해 채운다(백그라운드).
//  뷰 수명과 무관하게 완료되도록 @MainActor 객체가 소유한다(모델 컨텍스트 보유).
//

import Foundation
import SwiftData
import Observation

@MainActor
@Observable
final class PageCountFiller {
    private let modelContext: ModelContext
    private let service: any PageCountService

    init(modelContext: ModelContext, service: any PageCountService) {
        self.modelContext = modelContext
        self.service = service
    }

    /// 페이지 수가 없고 ISBN이 있으면 조회해 `totalPageCount`를 채운다. 실패/없음이면 조용히 무시.
    func fillIfNeeded(bookID: UUID, isbn: String?) {
        guard let isbn = isbn?.trimmingCharacters(in: .whitespacesAndNewlines), !isbn.isEmpty else { return }
        Task {
            guard let pages = await service.pageCount(isbn: isbn), pages > 0 else { return }
            let descriptor = FetchDescriptor<Book>(predicate: #Predicate { $0.id == bookID })
            guard let book = try? modelContext.fetch(descriptor).first,
                  book.totalPageCount == nil       // 그새 사용자가 직접 입력했으면 덮지 않음
            else { return }
            book.totalPageCount = pages
            try? modelContext.save()
        }
    }
}
