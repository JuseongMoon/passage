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
    let book: Book

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

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(book.title)
                        .font(.title2)
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
                .padding(.vertical, Theme.Spacing.xs)
            }

            Section("기록") {
                LabeledContent("총 독서시간", value: totalDuration > 0 ? totalDuration.readableDuration : "아직 없음")
                LabeledContent("세션", value: "\(completedSessions.count)회")
                LabeledContent("읽은 장소", value: placeNames.isEmpty ? "아직 없음" : placeNames.joined(separator: ", "))
            }
        }
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
