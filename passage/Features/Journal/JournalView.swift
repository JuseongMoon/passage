//
//  JournalView.swift
//  passage
//
//  저널 — 독서 기억의 타임라인. Phase 1에서 Book View / Place View로 확장. 상세 구현은 Phase 1.
//

import SwiftUI
import SwiftData

struct JournalView: View {
    @Query(
        filter: #Predicate<ReadingSession> { $0.endDate != nil },
        sort: \ReadingSession.startDate,
        order: .reverse
    ) private var sessions: [ReadingSession]

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    ContentUnavailableView {
                        Label("아직 남긴 독서가 없어요", systemImage: "book.closed")
                    } description: {
                        Text("독서를 마치면 이곳에 기억이 쌓여요.")
                    }
                } else {
                    List(sessions) { session in
                        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                            Text(session.book?.title ?? "제목 없는 책")
                                .font(.headline)
                                .fontDesign(.serif)
                            HStack(spacing: Theme.Spacing.xs) {
                                Text(session.duration.readableDuration)
                                if let place = session.place {
                                    Text("· \(place.name)")
                                }
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, Theme.Spacing.xxs)
                    }
                }
            }
            .navigationTitle("저널")
        }
    }
}

#Preview {
    JournalView()
        .modelContainer(PassageModelContainer.makePreview())
}
