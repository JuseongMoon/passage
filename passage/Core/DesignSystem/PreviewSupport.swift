//
//  PreviewSupport.swift
//  passage
//
//  프리뷰용 환경 주입 헬퍼. 컨테이너를 static let으로 보유해 유효 상태를 유지한다.
//  (SwiftData mainContext는 컨테이너를 강하게 보유하지 않으므로 보유가 필요)
//

import SwiftUI
import SwiftData

@MainActor
enum PreviewSupport {
    /// 프리뷰용 공유 인메모리 컨테이너.
    static let container: ModelContainer = PassageModelContainer.makePreview()

    /// 프리뷰 컨테이너에 삽입되는 샘플 책.
    static var sampleBook: Book {
        let book = Book(title: "데미안", author: "헤르만 헤세", totalPageCount: 240)
        container.mainContext.insert(book)
        return book
    }
}

extension View {
    /// 프리뷰에 앱 환경(컨테이너 · 의존성 · 세션 컨트롤러)을 주입한다.
    @MainActor
    func withPreviewEnvironment() -> some View {
        let container = PreviewSupport.container
        return self
            .modelContainer(container)
            .environment(AppDependencies())
            .environment(ReadingSessionController(modelContext: container.mainContext))
            .environment(PageCountFiller(modelContext: container.mainContext, service: StubPageCountService()))
            .environment(CoverColorFiller(modelContext: container.mainContext))
    }
}
