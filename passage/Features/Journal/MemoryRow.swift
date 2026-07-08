//
//  MemoryRow.swift
//  passage
//
//  저널 타임라인의 한 기억(세션) 행. 두 렌즈 모두 [강조 타이틀 + 메타] 대칭 구조로 통일한다.
//  책 렌즈(책으로 묶음)는 각 행의 주인공이 "장소", 장소 렌즈는 "책 제목". (→ DECISIONS #18)
//

import SwiftUI
import SwiftData

struct MemoryRow: View {
    let session: ReadingSession
    /// true(장소 렌즈)면 책 제목을, false(책 렌즈)면 장소를 각 행의 주인공으로 강조.
    let showsBook: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            title
            Text(meta)
                .font(.subheadline)
                .foregroundStyle(PassagePalette.inkMuted)
        }
        .padding(.vertical, Theme.Spacing.xxs)
    }

    // MARK: 주인공 타이틀 (렌즈에 따라 책/장소)

    @ViewBuilder private var title: some View {
        if showsBook {
            Text(session.book?.title ?? "제목 없는 책")
                .font(.headline)
                .fontDesign(.serif)          // 책 제목 = 문학적 톤
                .foregroundStyle(PassagePalette.ink)
                .lineLimit(1)
        } else if let name = session.place?.name, !name.isEmpty {
            HStack(spacing: Theme.Spacing.xxs) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.subheadline)
                    .foregroundStyle(PassagePalette.warmAccent)   // 위치 핀 웜 액센트
                Text(name)
                    .font(.headline)
                    .foregroundStyle(PassagePalette.ink)
                    .lineLimit(1)
            }
        } else {
            Text("장소 기록 없음")
                .font(.headline)
                .foregroundStyle(PassagePalette.inkMuted)
        }
    }

    private var meta: String {
        let date = session.startDate.formatted(date: .abbreviated, time: .omitted)
        return "\(date) · \(session.duration.readableDuration)"
    }
}

#Preview("셀 — 두 렌즈 비교") {
    let container = PassageModelContainer.makePreview()
    let ctx = container.mainContext
    let book = Book(title: "작별하지 않는다", author: "한강")
    let place = Place(name: "연희동 카페")
    ctx.insert(book); ctx.insert(place)
    let s = ReadingSession(book: book, startPage: 0)
    s.endPage = 88; s.duration = 70 * 60; s.endDate = .now; s.place = place
    ctx.insert(s)

    return List {
        Section {
            MemoryRow(session: s, showsBook: false)
                .listRowBackground(PassagePalette.cardBody)
        } header: {
            Text("책 렌즈 — 장소가 주인공").textCase(nil)
        }
        Section {
            MemoryRow(session: s, showsBook: true)
                .listRowBackground(PassagePalette.cardBody)
        } header: {
            Text("장소 렌즈 — 책이 주인공").textCase(nil)
        }
    }
    .listStyle(.insetGrouped)
    .scrollContentBackground(.hidden)
    .background(PassagePalette.appBg)
    .modelContainer(container)
}
