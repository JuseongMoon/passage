//
//  AddQuoteView.swift
//  passage
//
//  책에 인용구를 남긴다. 구절(필수) · 페이지(선택).
//

import SwiftUI
import SwiftData
import UIKit

struct AddQuoteView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let book: Book

    @State private var text = ""
    @State private var pageText = ""

    private var canSave: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("구절") {
                    TextEditor(text: $text)
                        .frame(minHeight: 120)
                        .overlay(alignment: .topLeading) {
                            if text.isEmpty {
                                Text("마음에 남은 구절을 옮겨 적어보세요…")
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                                    .allowsHitTesting(false)
                            }
                        }
                }
                Section("페이지 (선택)") {
                    TextField("페이지", text: $pageText)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("인용구")
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
        let quote = Quote(
            text: text.trimmingCharacters(in: .whitespacesAndNewlines),
            page: Int(pageText),
            book: book
        )
        modelContext.insert(quote)
        dismiss()
    }
}
