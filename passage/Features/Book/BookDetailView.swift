//
//  BookDetailView.swift
//  passage
//
//  책 상세 + 책별 요약(총 독서시간 · 세션 수 · 읽은 장소).
//  모든 통계는 ReadingSession에서 파생한다. (Session is Source of Truth)
//

import SwiftUI
import SwiftData

struct BookDetailView: View {
    @Environment(ReadingSessionController.self) private var sessionController
    let book: Book
    @State private var addingQuote = false

    private var completedSessions: [ReadingSession] {
        (book.sessions ?? []).filter { $0.endDate != nil }
    }
    private var totalDuration: TimeInterval {
        completedSessions.reduce(0) { $0 + $1.duration }
    }
    private var placeNames: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for session in completedSessions {
            if let name = session.place?.name, !name.isEmpty, seen.insert(name).inserted {
                result.append(name)
            }
        }
        return result
    }
    private var sortedQuotes: [Quote] {
        (book.quotes ?? []).sorted { $0.dateCreated > $1.dateCreated }
    }

    var body: some View {
        List {
            Section {
                HStack(alignment: .top, spacing: Theme.Spacing.md) {
                    BookCoverView(urlString: book.coverRemoteURL)
                        .frame(width: 80, height: 120)
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text(book.title)
                            .font(.title3)
                            .fontDesign(.serif)
                            .fontWeight(.semibold)
                        if !book.author.isEmpty {
                            Text(book.author).foregroundStyle(.secondary)
                        }
                        if let isbn = book.isbn, !isbn.isEmpty {
                            Text("ISBN \(isbn)")
                                .font(.footnote)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    Spacer()
                }
                .padding(.vertical, Theme.Spacing.xs)
            }

            if !sessionController.isFlowActive {
                Section {
                    Button {
                        sessionController.beginReading(book: book)
                    } label: {
                        Label("읽기 시작", systemImage: "play.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }

            Section("기록") {
                LabeledContent("총 독서시간", value: totalDuration > 0 ? totalDuration.readableDuration : "아직 없음")
                LabeledContent("세션", value: "\(completedSessions.count)회")
                LabeledContent("읽은 장소", value: placeNames.isEmpty ? "아직 없음" : placeNames.joined(separator: ", "))
            }

            Section("인용구") {
                ForEach(sortedQuotes) { quote in
                    VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                        Text(quote.text)
                            .fontDesign(.serif)
                        if let page = quote.page {
                            Text("\(page)p")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, Theme.Spacing.xxs)
                }
                Button {
                    addingQuote = true
                } label: {
                    Label("인용구 추가", systemImage: "quote.opening")
                }
            }
        }
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $addingQuote) {
            AddQuoteView(book: book)
        }
    }
}

#Preview {
    NavigationStack {
        BookDetailView(book: PreviewSupport.sampleBook)
    }
    .withPreviewEnvironment()
}
