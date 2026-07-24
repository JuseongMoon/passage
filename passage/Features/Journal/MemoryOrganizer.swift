//
//  MemoryOrganizer.swift
//  passage
//
//  저널의 두 렌즈(책/장소)로 완료된 세션을 묶는 순수 로직. (뷰에서 분리해 테스트 가능)
//

import Foundation

enum JournalLens: String, CaseIterable, Identifiable {
    case book, place
    var id: String { rawValue }
    var label: String { self == .book ? "책" : "장소" }
}

struct MemoryGroup: Identifiable {
    let id: String
    let title: String
    let sessions: [ReadingSession]
    let mostRecent: Date
}

enum MemoryOrganizer {
    /// 완료된 세션들을 렌즈 기준으로 묶어 그룹의 최신 세션 순으로 정렬한다.
    static func grouped(_ sessions: [ReadingSession], by lens: JournalLens) -> [MemoryGroup] {
        let keyed: [String: [ReadingSession]]
        switch lens {
        case .book:
            keyed = Dictionary(grouping: sessions) { $0.book?.id.uuidString ?? "no-book" }
        case .place:
            keyed = Dictionary(grouping: sessions) { $0.place?.id.uuidString ?? "no-place" }
        }

        return keyed.map { key, group -> MemoryGroup in
            let sorted = group.sorted { $0.startDate > $1.startDate }
            let title: String
            switch lens {
            case .book:
                let t = sorted.first?.book?.displayTitle ?? ""
                title = t.isEmpty ? "제목 없는 책" : t
            case .place:
                let n = sorted.first?.place?.name ?? ""
                title = n.isEmpty ? "장소 없음" : n
            }
            return MemoryGroup(
                id: "\(lens.rawValue)-\(key)",
                title: title,
                sessions: sorted,
                mostRecent: sorted.first?.startDate ?? .distantPast
            )
        }
        .sorted { $0.mostRecent > $1.mostRecent }
    }
}
