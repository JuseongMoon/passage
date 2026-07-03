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
        let book = Book(
            title: trimmedTitle,
            author: author.trimmingCharacters(in: .whitespacesAndNewlines),
            isbn: isbn.isEmpty ? nil : isbn.trimmingCharacters(in: .whitespaces),
            totalPageCount: Int(totalPages)
        )
        modelContext.insert(book)
        dismiss()
    }
}

#Preview {
    AddBookView()
        .modelContainer(PassageModelContainer.makePreview())
}
