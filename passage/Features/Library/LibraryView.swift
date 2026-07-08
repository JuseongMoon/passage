//
//  LibraryView.swift
//  passage
//
//  서재 홈 — 책 한 권을 "보딩패스"로 쌓아 보여준다. (목업 재구성)
//  맨 앞 패스만 펼쳐져 책 정보·최근 여정기록·진행률·"여정 시작하기"를 보여준다.
//  책별 통계는 전부 세션에서 파생한다(PassPresentation). Session is Source of Truth.
//

import SwiftUI
import SwiftData

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppDependencies.self) private var dependencies
    @Environment(ReadingSessionController.self) private var sessionController

    @Query(sort: \Book.dateAdded, order: .reverse) private var books: [Book]

    @State private var showingAddBook = false
    @State private var front = 0                 // 펼친 패스(0 = 가장 최근)
    @State private var bookPendingDelete: Book?
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                PassagePalette.appBg.ignoresSafeArea()

                if books.isEmpty {
                    emptyState
                } else {
                    content
                }
            }
            .toolbar(.hidden, for: .navigationBar)   // 커스텀 헤더 사용
            .navigationDestination(for: Book.self) { book in
                BookDetailView(book: book)
            }
            .sheet(isPresented: $showingAddBook) {
                BookSearchView()
            }
            .confirmationDialog(
                deleteTitle,
                isPresented: deleteDialogBinding,
                titleVisibility: .visible
            ) {
                Button("책 삭제하기", role: .destructive) { performDelete() }
                Button("취소", role: .cancel) { bookPendingDelete = nil }
            } message: {
                Text("이 책의 모든 독서 기록과 여정이 함께 삭제되며, 되돌릴 수 없어요.")
            }
        }
        .onChange(of: books.count) { _, _ in
            front = min(front, max(0, books.count - 1))
        }
    }

    // MARK: 본문

    private var content: some View {
        VStack(spacing: 0) {
            headerView
            PassStackView(
                passes: PassPresentation.list(from: books),
                front: $front,
                onAddBook: { showingAddBook = true },
                onStartSession: { startSession(at: $0) },
                onViewJourney: { viewJourney(at: $0) },
                onDelete: { askDelete(at: $0) }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Passage")
                .font(.system(size: 19, weight: .light))
                .foregroundStyle(PassagePalette.ink)
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(libraryTitle)
                    .font(.system(size: 28))
                    .foregroundStyle(PassagePalette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("현재 \(books.count)권의 책을 읽고 있어요")
                    .font(.system(size: 12))
                    .foregroundStyle(PassagePalette.inkMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.top, Theme.Spacing.sm)
        .padding(.bottom, Theme.Spacing.xs)
    }

    private var emptyState: some View {
        VStack(spacing: 0) {
            headerView
            Spacer()
            ContentUnavailableView {
                Label("아직 서재가 비어 있어요", systemImage: "books.vertical")
            } description: {
                Text("첫 책을 더해 첫 기억을 만들어 보세요.")
            } actions: {
                Button("새 책 추가하기") { showingAddBook = true }
                    .buttonStyle(.borderedProminent)
                    .tint(PassagePalette.warmAccent)
            }
            Spacer()
        }
    }

    // MARK: 동작

    private var libraryTitle: String {
        if let name = dependencies.auth.currentUser?.displayName, !name.isEmpty {
            return "\(name)님의 서재"
        }
        return "나의 서재"
    }

    private func startSession(at index: Int) {
        guard books.indices.contains(index) else { return }
        sessionController.beginReading(book: books[index])
    }

    private func viewJourney(at index: Int) {
        guard books.indices.contains(index) else { return }
        path.append(books[index])
    }

    private func askDelete(at index: Int) {
        guard books.indices.contains(index) else { return }
        bookPendingDelete = books[index]
    }

    private func performDelete() {
        guard let book = bookPendingDelete else { return }
        modelContext.delete(book)      // cascade: 세션·인용구 함께 삭제
        try? modelContext.save()
        bookPendingDelete = nil
        front = 0
    }

    private var deleteDialogBinding: Binding<Bool> {
        Binding(
            get: { bookPendingDelete != nil },
            set: { if !$0 { bookPendingDelete = nil } }
        )
    }

    private var deleteTitle: String {
        "'\(bookPendingDelete?.title ?? "")'을(를) 삭제할까요?"
    }
}

#Preview("빈 서재") {
    LibraryView().withPreviewEnvironment()
}

#Preview("패스 스택") {
    let container = PassageModelContainer.makePreview()
    let ctx = container.mainContext

    func addBook(_ title: String, _ author: String, pages: Int?, addedDaysAgo: Double) -> Book {
        let book = Book(title: title, author: author, totalPageCount: pages)
        book.dateAdded = Date(timeIntervalSinceNow: -86_400 * addedDaysAgo)
        ctx.insert(book)
        return book
    }
    func addSession(_ book: Book, start: Int?, end: Int?, minutes: Double, daysAgo: Double, place: Place?) {
        let s = ReadingSession(book: book, startPage: start)
        s.endPage = end
        s.duration = minutes * 60
        s.endDate = Date(timeIntervalSinceNow: -86_400 * daysAgo)
        s.place = place
        ctx.insert(s)
    }

    let home = Place(name: "집"); let store = Place(name: "동네 서점"); let cafe = Place(name: "연희동 카페")
    ctx.insert(home); ctx.insert(store); ctx.insert(cafe)

    let farewell = addBook("작별하지 않는다", "한강", pages: 340, addedDaysAgo: 1)
    addSession(farewell, start: 0, end: 88, minutes: 60, daysAgo: 3, place: home)
    addSession(farewell, start: 88, end: 176, minutes: 70, daysAgo: 1, place: store)

    let years = addBook("연년세세", "황정은", pages: 264, addedDaysAgo: 4)
    addSession(years, start: 0, end: 52, minutes: 45, daysAgo: 5, place: cafe)

    let rapids = addBook("급류", "정대건", pages: nil, addedDaysAgo: 7)   // 페이지 수 없음 → 폴백
    addSession(rapids, start: 10, end: 34, minutes: 30, daysAgo: 6, place: home)

    _ = addBook("데미안", "헤르만 헤세", pages: 240, addedDaysAgo: 10)     // 세션 없음

    return LibraryView()
        .modelContainer(container)
        .environment(AppDependencies())
        .environment(ReadingSessionController(modelContext: ctx))
}
