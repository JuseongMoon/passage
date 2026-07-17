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
    @Environment(CoverColorFiller.self) private var coverColorFiller
    @Environment(AppRouter.self) private var router

    @Query(sort: \Book.dateAdded, order: .reverse) private var books: [Book]

    @State private var showingAddBook = false
    @State private var front = 0                 // 펼친 패스(0 = 가장 최근)
    @State private var libraryFilter: LibraryFilter = .all
    @State private var bookPendingDelete: Book?
    @State private var bookPendingPageCount: Book?
    @State private var pageCountText = ""

    var body: some View {
        NavigationStack {
            ZStack {
                PassagePalette.appBg.ignoresSafeArea()

                if books.isEmpty {
                    emptyState
                } else {
                    content
                }
            }
            .toolbar(.hidden, for: .navigationBar)   // 커스텀 헤더 사용
            .sheet(isPresented: $showingAddBook) {
                BookSearchView()
            }
            .passageConfirmModal(
                item: $bookPendingDelete,
                title: { "'\($0.title)'을(를) 삭제할까요?" },
                message: "이 책의 모든 독서 기록과 여정이 함께 삭제되며, 되돌릴 수 없어요.",
                confirmTitle: "삭제하기",
                onConfirm: { performDelete($0) }
            )
            .alert("전체 페이지 수", isPresented: pageCountDialogBinding) {
                TextField("예: 320", text: $pageCountText)
                    .keyboardType(.numberPad)
                Button("저장") { savePageCount() }
                Button("취소", role: .cancel) { bookPendingPageCount = nil }
            } message: {
                Text("전체 페이지 수를 입력하면 독서 진행률(바코드)이 보여요.")
            }
        }
        .onChange(of: books.count) { _, _ in
            front = min(front, max(0, books.count - 1))
        }
        .onChange(of: libraryFilter) { _, _ in
            front = 0   // 필터가 바뀌면 목록이 달라지므로 맨 앞으로
        }
        .task {
            coverColorFiller.backfillMissing()   // 표지색 미추출 책을 백그라운드로 채움(멱등)
        }
    }

    // MARK: 본문

    private var content: some View {
        VStack(spacing: 0) {
            headerView
            PassStackView(
                passes: PassPresentation.list(from: filteredBooks),
                front: $front,
                onStartSession: { startSession(at: $0) },
                onViewJourney: { viewJourney(at: $0) },
                onDelete: { askDelete(at: $0) },
                onSetPageCount: { promptPageCount(at: $0) }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var headerView: some View {
        PassageScreenHeader(
            eyebrow: "Passage",
            title: libraryTitle,
            subtitle: "현재 \(books.count)권의 책을 읽고 있어요"
        ) {
            HStack(spacing: Theme.Spacing.xs) {
                filterMenu
                addBookButton
            }
        }
    }

    /// 헤더 우측 "+ 책 추가"(목업) — 스택 위 알약 대신 헤더로 올렸다.
    private var addBookButton: some View {
        Button { showingAddBook = true } label: {
            HStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                Text("책 추가")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundStyle(PassagePalette.appBg)
            .padding(.vertical, 7)
            .padding(.horizontal, Theme.Spacing.sm)
            .background(PassagePalette.ink, in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("새 책 추가하기")
    }

    private var filterMenu: some View {
        Menu {
            ForEach(LibraryFilter.allCases) { option in
                Button {
                    libraryFilter = option
                } label: {
                    if libraryFilter == option {
                        Label(option.label, systemImage: "checkmark")
                    } else {
                        Text(option.label)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(libraryFilter.label)
                    .font(.system(size: 14, weight: .medium))
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(PassagePalette.ink)
            .padding(.vertical, 6)
            .padding(.horizontal, Theme.Spacing.sm)
            .background(PassagePalette.cardBody, in: .capsule)
        }
        .accessibilityLabel("책 필터, 현재 \(libraryFilter.label)")
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

    /// 현재 필터가 적용된 책 목록 — 카드 스택·콜백 인덱스의 기준(전체 books가 아니라 이 배열).
    private var filteredBooks: [Book] {
        books.filter(libraryFilter.matches)
    }

    private func startSession(at index: Int) {
        guard filteredBooks.indices.contains(index) else { return }
        sessionController.beginReading(book: filteredBooks[index])
    }

    private func viewJourney(at index: Int) {
        guard filteredBooks.indices.contains(index) else { return }
        router.openJourney(bookID: filteredBooks[index].id)   // 독서여정 탭으로 건너가 그 책을 포커스
    }

    private func askDelete(at index: Int) {
        guard filteredBooks.indices.contains(index) else { return }
        bookPendingDelete = filteredBooks[index]
    }

    private func performDelete(_ book: Book) {
        modelContext.delete(book)      // cascade: 세션·인용구 함께 삭제
        try? modelContext.save()
        front = 0
    }

    private func promptPageCount(at index: Int) {
        guard filteredBooks.indices.contains(index) else { return }
        let book = filteredBooks[index]
        pageCountText = book.totalPageCount.map(String.init) ?? ""
        bookPendingPageCount = book
    }

    private func savePageCount() {
        guard let book = bookPendingPageCount else { return }
        book.totalPageCount = Int(pageCountText).flatMap { $0 > 0 ? $0 : nil }
        try? modelContext.save()
        bookPendingPageCount = nil
    }

    private var pageCountDialogBinding: Binding<Bool> {
        Binding(
            get: { bookPendingPageCount != nil },
            set: { if !$0 { bookPendingPageCount = nil } }
        )
    }
}

/// 서재 필터(모든 책/읽는 중/완독) — 완독 여부(book.isFinished) 기준.
enum LibraryFilter: String, CaseIterable, Identifiable {
    case all, reading, finished

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: "모든 책"
        case .reading: "읽는 중"
        case .finished: "완독"
        }
    }

    func matches(_ book: Book) -> Bool {
        switch self {
        case .all: true
        case .reading: !book.isFinished
        case .finished: book.isFinished
        }
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
        .environment(CoverColorFiller(modelContext: ctx))
}
