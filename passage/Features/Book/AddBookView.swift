//
//  AddBookView.swift
//  passage
//
//  책 수동 등록. 제목만 있으면 저장 가능(저자·ISBN·페이지는 선택).
//  검색/ISBN 자동 등록은 Phase 1a 후속(BookSearchService).
//

import SwiftUI
import SwiftData
import UIKit   // UIKeyboardType(.keyboardType) 사용

struct AddBookView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(PageCountFiller.self) private var pageCountFiller

    @State private var title = ""
    @State private var author = ""
    @State private var isbn = ""
    @State private var totalPages = ""

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private var canSave: Bool { !trimmedTitle.isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("책") {
                    TextField("제목", text: $title)
                    TextField("저자", text: $author)
                }
                Section("선택") {
                    TextField("ISBN", text: $isbn)
                        .keyboardType(.numbersAndPunctuation)
                    TextField("전체 페이지 수", text: $totalPages)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("책 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장", action: save).disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        // 0·음수는 "모름"으로 본다 — 전체 페이지 수는 페이지 값의 상한이라 잘못된 값이 들어가면 안 된다.
        let total = PageRules.normalizedTotal(Int(totalPages.filter(\.isNumber)))
        let book = Book(
            title: trimmedTitle,
            author: author.trimmingCharacters(in: .whitespacesAndNewlines),
            isbn: isbn.isEmpty ? nil : isbn.trimmingCharacters(in: .whitespaces),
            totalPageCount: total
        )
        modelContext.insert(book)
        if total == nil {   // 페이지 수 안 넣었으면 ISBN으로 보조 조회
            pageCountFiller.fillIfNeeded(bookID: book.id, isbn: isbn.isEmpty ? nil : isbn)
        }
        dismiss()
    }
}

#Preview {
    AddBookView()
        .environment(PageCountFiller(modelContext: PreviewSupport.container.mainContext, service: StubPageCountService()))
        .modelContainer(PreviewSupport.container)
}
