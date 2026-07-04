//
//  LibraryView.swift
//  passage
//
//  서재 — 책 목록. 책 추가(수동), 책 탭 시 상세로 이동.
//  책별 요약은 BookDetailView에서 세션 기반으로 계산.
//

import SwiftUI
import SwiftData

struct LibraryView: View {
    @Query(sort: \Book.dateAdded, order: .reverse) private var books: [Book]
    @State private var showingAddBook = false

    var body: some View {
        NavigationStack {
            Group {
                if books.isEmpty {
                    ContentUnavailableView {
                        Label("아직 서재가 비어 있어요", systemImage: "books.vertical")
                    } description: {
                        Text("첫 책을 더해 첫 기억을 만들어 보세요.")
                    } actions: {
                        Button("책 추가") { showingAddBook = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(books) { book in
                            NavigationLink {
                                BookDetailView(book: book)
                            } label: {
                                bookRow(book)
                            }
                        }
                    }
                }
            }
            .navigationTitle("서재")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddBook = true
                    } label: {
                        Label("책 추가", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddBook) {
                AddBookView()
            }
        }
    }

    private func bookRow(_ book: Book) -> some View {
        let completed = (book.sessions ?? []).filter { $0.endDate != nil }
        let totalTime = completed.reduce(0) { $0 + $1.duration }
        return VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            Text(book.title)
                .font(.headline)
                .fontDesign(.serif)
            if !book.author.isEmpty {
                Text(book.author)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if !completed.isEmpty {
                Text("\(totalTime.readableDuration) · \(completed.count)세션")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, Theme.Spacing.xxs)
    }
}

#Preview {
    LibraryView()
        .modelContainer(PassageModelContainer.makePreview())
}
