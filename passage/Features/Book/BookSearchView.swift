//
//  BookSearchView.swift
//  passage
//
//  책 검색(Google Books) → 결과 선택으로 등록. 못 찾으면 "직접 입력"(수동)으로.
//

import SwiftUI
import SwiftData

struct BookSearchView: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var results: [BookSearchResult] = []
    @State private var isSearching = false
    @State private var hasSearched = false
    @State private var failed = false
    @State private var showingManual = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(results) { result in
                    Button {
                        add(result)
                    } label: {
                        BookSearchResultRow(result: result)
                    }
                    .buttonStyle(.plain)
                }
            }
            .overlay { statusOverlay }
            .searchable(text: $query, prompt: "제목, 저자, ISBN")
            .onSubmit(of: .search) { runSearch() }
            .onChange(of: query) { _, newValue in
                if newValue.isEmpty {
                    results = []
                    hasSearched = false
                    failed = false
                }
            }
            .navigationTitle("책 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("직접 입력") { showingManual = true }
                }
            }
            .sheet(isPresented: $showingManual) {
                AddBookView()
            }
        }
    }

    @ViewBuilder private var statusOverlay: some View {
        if isSearching {
            ProgressView()
        } else if results.isEmpty {
            if failed {
                ContentUnavailableView {
                    Label("검색하지 못했어요", systemImage: "wifi.slash")
                } description: {
                    Text("잠시 후 다시 시도하거나 '직접 입력'으로 추가해 보세요.")
                }
            } else if hasSearched {
                ContentUnavailableView.search(text: query)
            } else {
                ContentUnavailableView {
                    Label("책을 검색해 보세요", systemImage: "magnifyingglass")
                } description: {
                    Text("제목 · 저자 · ISBN으로 찾을 수 있어요.")
                }
            }
        }
    }

    private func runSearch() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isSearching = true
        failed = false
        Task {
            do {
                results = try await dependencies.bookSearch.search(query: trimmed)
            } catch {
                results = []
                failed = true
            }
            hasSearched = true
            isSearching = false
        }
    }

    private func add(_ result: BookSearchResult) {
        // 같은 ISBN이 이미 있으면 중복 등록하지 않는다. (CloudKit unique 미지원 → 앱단 dedup)
        if let isbn = result.isbn,
           let existing = try? modelContext.fetch(
               FetchDescriptor<Book>(predicate: #Predicate { $0.isbn == isbn })
           ),
           !existing.isEmpty {
            dismiss()
            return
        }
        let book = Book(
            title: result.title,
            author: result.author,
            isbn: result.isbn,
            totalPageCount: result.pageCount,
            coverRemoteURL: result.coverURL
        )
        modelContext.insert(book)
        dismiss()
    }
}

private struct BookSearchResultRow: View {
    let result: BookSearchResult

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            BookCoverView(urlString: result.coverURL)
                .frame(width: 44, height: 66)
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(result.title)
                    .font(.headline)
                    .fontDesign(.serif)
                    .lineLimit(2)
                if !result.author.isEmpty {
                    Text(result.author)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(.vertical, Theme.Spacing.xxs)
        .contentShape(.rect)
    }
}
