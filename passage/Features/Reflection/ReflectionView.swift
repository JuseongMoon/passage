//
//  ReflectionView.swift
//  passage
//
//  잔잔한 회고 — 한 해 동안 함께한 책·구절·머문 곳을 조용히 되돌아본다.
//  수치·순위·경쟁 없이. (Memory over Productivity)
//

import SwiftUI
import SwiftData

struct ReflectionView: View {
    @Query private var sessions: [ReadingSession]
    @Query private var quotes: [Quote]
    @State private var selectedYear: Int?

    private var years: [Int] { ReflectionOrganizer.availableYears(sessions) }

    var body: some View {
        NavigationStack {
            Group {
                if let year = selectedYear ?? years.first {
                    content(for: year)
                } else {
                    ContentUnavailableView {
                        Label("아직 남긴 기억이 없어요", systemImage: "book.closed")
                    } description: {
                        Text("책을 읽고 기억을 남기면 이곳에서 조용히 되돌아볼 수 있어요.")
                    }
                }
            }
            .navigationTitle("회고")
            .toolbar {
                if years.count > 1, let current = selectedYear ?? years.first {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            ForEach(years, id: \.self) { year in
                                Button(String(year)) { selectedYear = year }
                            }
                        } label: {
                            Label(String(current), systemImage: "calendar")
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder private func content(for year: Int) -> some View {
        let digest = ReflectionOrganizer.digest(year: year, sessions: sessions, quotes: quotes)
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text(String(year))
                        .font(.system(size: 44, weight: .light, design: .serif))
                    Text("함께 읽은 기억")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                if digest.books.isEmpty && digest.quotes.isEmpty && digest.places.isEmpty {
                    Text("이 해엔 아직 남긴 기억이 없어요.")
                        .foregroundStyle(.secondary)
                        .padding(.vertical, Theme.Spacing.xl)
                } else {
                    if !digest.books.isEmpty { booksSection(digest.books) }
                    if !digest.quotes.isEmpty { quotesSection(digest.quotes) }
                    if !digest.places.isEmpty { placesSection(digest.places) }
                }
            }
            .padding(Theme.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func booksSection(_ books: [Book]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            sectionTitle("함께한 책")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: Theme.Spacing.md) {
                    ForEach(books) { book in
                        NavigationLink {
                            BookDetailView(book: book)
                        } label: {
                            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                                BookCoverView(urlString: book.coverRemoteURL)
                                    .frame(width: 92, height: 138)
                                Text(book.title)
                                    .font(.caption)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                    .frame(width: 92, alignment: .leading)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func quotesSection(_ quotes: [Quote]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            sectionTitle("마음에 남은 구절")
            ForEach(quotes.prefix(6)) { quote in
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text("“\(quote.text)”")
                        .fontDesign(.serif)
                    if let title = quote.book?.title, !title.isEmpty {
                        Text("— \(title)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func placesSection(_ places: [Place]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            sectionTitle("머문 곳")
            ForEach(places) { place in
                Label(place.name, systemImage: "mappin.and.ellipse")
                    .font(.subheadline)
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.headline)
            .foregroundStyle(.secondary)
    }
}

#Preview {
    ReflectionView().withPreviewEnvironment()
}
