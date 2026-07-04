//
//  NoteEditorView.swift
//  passage
//
//  독서 세션에 남기는 한 줄 회고(생각). 조용한 글쓰기 화면. (Memory over Productivity)
//

import SwiftUI
import SwiftData

struct NoteEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let session: ReadingSession

    @State private var text: String

    init(session: ReadingSession) {
        self.session = session
        _text = State(initialValue: session.note ?? "")
    }

    var body: some View {
        NavigationStack {
            TextEditor(text: $text)
                .padding(Theme.Spacing.md)
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("이 독서에 대한 생각을 남겨보세요…")
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, Theme.Spacing.md + 5)
                            .padding(.vertical, Theme.Spacing.md + 8)
                            .allowsHitTesting(false)
                    }
                }
                .navigationTitle("생각")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("취소") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("저장") { save() }
                    }
                }
        }
    }

    private func save() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        session.note = trimmed.isEmpty ? nil : trimmed
        try? modelContext.save()
        dismiss()
    }
}
