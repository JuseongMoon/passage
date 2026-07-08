//
//  BookSearchView.swift
//  passage
//
//  새 책 추가 — 바텀시트. 제목·저자·ISBN으로 검색(Naver)해 고른다. 못 찾으면 "직접 입력".
//  (목업 "새 책 추가하기" 재구성)
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
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var searchFocused: Bool

    /// previewQuery는 프리뷰에서 결과 상태를 보여주기 위한 초기값(실앱은 빈 값 → 무동작).
    init(previewQuery: String = "") {
        _query = State(initialValue: previewQuery)
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            header
            searchField
            content
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.top, Theme.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(PassagePalette.appBg)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onChange(of: query) { _, newValue in scheduleSearch(newValue) }
        .sheet(isPresented: $showingManual) { AddBookView() }
        .task {
            if !trimmedQuery.isEmpty && !hasSearched {   // 프리뷰 초기 쿼리용
                await performSearch(trimmedQuery)
            }
        }
    }

    // MARK: 헤더 · 검색 필드

    private var header: some View {
        HStack {
            Text("새 책 추가하기")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(PassagePalette.ink)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(PassagePalette.ink)
                    .frame(width: 28, height: 28)
                    .background(PassagePalette.ink.opacity(0.08), in: .circle)
            }
            .accessibilityLabel("닫기")
        }
    }

    private var searchField: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(PassagePalette.inkMuted)
            TextField("제목, 저자, ISBN으로 검색", text: $query)
                .focused($searchFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .foregroundStyle(PassagePalette.ink)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(PassagePalette.inkFaint)
                }
                .accessibilityLabel("검색어 지우기")
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .frame(height: 46)
        .background(
            Capsule()
                .fill(PassagePalette.field)
                .stroke(PassagePalette.hairline, lineWidth: 1.5)
        )
    }

    // MARK: 콘텐츠 상태

    @ViewBuilder private var content: some View {
        if trimmedQuery.isEmpty {
            centeredState(
                title: "책을 검색해 보세요",
                subtitle: "제목, 저자, ISBN으로 찾을 수 있어요."
            )
        } else if isSearching && results.isEmpty {
            Spacer()
            ProgressView()
            Spacer()
        } else if failed {
            centeredState(
                title: "검색하지 못했어요",
                subtitle: "잠시 후 다시 시도하거나 직접 입력해 보세요.",
                showManualButton: true
            )
        } else if results.isEmpty && hasSearched {
            centeredState(
                title: "검색 결과가 없어요",
                subtitle: "다른 검색어로 찾거나 직접 입력해 보세요.",
                showManualButton: true
            )
        } else {
            resultsList
        }
    }

    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: Theme.Spacing.xxs) {
                ForEach(results) { result in
                    Button { add(result) } label: { resultRow(result) }
                        .buttonStyle(.plain)
                }
            }
            .padding(.bottom, Theme.Spacing.lg)
        }
        .scrollDismissesKeyboard(.immediately)
    }

    private func resultRow(_ result: BookSearchResult) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            BookCoverView(urlString: result.coverURL)
                .frame(width: 38, height: 54)
                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(result.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(PassagePalette.ink)
                    .lineLimit(1)
                if !result.author.isEmpty {
                    Text(result.author)
                        .font(.system(size: 11.5))
                        .foregroundStyle(PassagePalette.inkMuted)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: Theme.Spacing.sm)
            Text("+ 추가")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(PassagePalette.ink)
        }
        .padding(Theme.Spacing.xs)
        .contentShape(.rect)
    }

    private func centeredState(title: String, subtitle: String, showManualButton: Bool = false) -> some View {
        VStack(spacing: Theme.Spacing.xs) {
            Spacer()
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(PassagePalette.ink)
            Text(subtitle)
                .font(.system(size: 12.5))
                .foregroundStyle(PassagePalette.inkMuted)
                .multilineTextAlignment(.center)
            if showManualButton {
                Button("직접 입력") { showingManual = true }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(PassagePalette.warmAccent)
                    .padding(.top, Theme.Spacing.xs)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: 검색(디바운스) · 등록

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func scheduleSearch(_ raw: String) {
        searchTask?.cancel()
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = []
            hasSearched = false
            failed = false
            isSearching = false
            return
        }
        isSearching = true
        failed = false
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(400))   // 디바운스
            guard !Task.isCancelled else { return }
            await performSearch(trimmed)
        }
    }

    private func performSearch(_ trimmed: String) async {
        do {
            let found = try await dependencies.bookSearch.search(query: trimmed)
            guard !Task.isCancelled else { return }
            results = found
            failed = false
        } catch {
            guard !Task.isCancelled else { return }
            results = []
            failed = true
        }
        hasSearched = true
        isSearching = false
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

private struct PreviewBookSearch: BookSearchService {
    func search(query: String) async throws -> [BookSearchResult] {
        [
            BookSearchResult(title: "작별하지 않는다", author: "한강", isbn: "1", coverURL: nil, pageCount: 340),
            BookSearchResult(title: "소년이 온다", author: "한강", isbn: "2", coverURL: nil, pageCount: 216),
            BookSearchResult(title: "흰", author: "한강", isbn: "3", coverURL: nil, pageCount: 132),
        ]
    }
    func lookup(isbn: String) async throws -> BookSearchResult? { nil }
}

#Preview("검색 전") {
    BookSearchView().withPreviewEnvironment()
}

#Preview("검색 결과") {
    BookSearchView(previewQuery: "한")
        .environment(AppDependencies(bookSearch: PreviewBookSearch()))
        .modelContainer(PassageModelContainer.makePreview())
}
