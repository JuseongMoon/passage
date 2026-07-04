//
//  MemoryRow.swift
//  passage
//
//  저널 타임라인의 한 기억(세션) 행. 렌즈에 따라 책 또는 장소를 강조한다.
//

import SwiftUI

struct MemoryRow: View {
    let session: ReadingSession
    /// 장소 렌즈에서는 책 제목을, 책 렌즈에서는 장소를 함께 보인다.
    let showsBook: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            if showsBook {
                Text(session.book?.title ?? "제목 없는 책")
                    .font(.headline)
                    .fontDesign(.serif)
            }
            HStack(spacing: Theme.Spacing.xxs) {
                Text(session.startDate.formatted(date: .abbreviated, time: .omitted))
                Text("·")
                Text(session.duration.readableDuration)
                if !showsBook, let name = session.place?.name, !name.isEmpty {
                    Text("· \(name)")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, Theme.Spacing.xxs)
    }
}
