//
//  PassPresentation.swift
//  passage
//
//  Book + 세션 → "패스" 카드가 그릴 값. 전부 파생 계산이다. (Session is Source of Truth)
//  순수 값 타입 — 뷰에서 분리해 단위 테스트로 검증한다. (→ PassPresentationTests)
//

import Foundation

/// 최근 여정기록 한 줄(펼친 패스에 최대 2개 표시).
struct PassJourney: Identifiable, Hashable, Sendable {
    let id: UUID          // 세션 id
    let place: String     // 장소 이름(없으면 "장소 없음")
    let meta: String      // "45분 · 16p" / "45분"
    let date: String      // "6월 22일 (일)"
}

/// 한 책을 나타내는 패스의 표시 값.
struct PassPresentation: Identifiable, Hashable, Sendable {
    let id: UUID          // 책 id
    let title: String
    let author: String
    let coverURL: String?
    let swatch: PassagePalette.Swatch

    let totalDuration: TimeInterval
    /// 티켓에 크게 찍는 총 독서시간. 기록이 없으면 "아직 기록 없음".
    let totalDurationText: String
    let sessionCount: Int

    /// 최근 여정기록 0~2개(최신순).
    let recentJourneys: [PassJourney]

    /// 진행률 0~1. `totalPageCount`나 완료 페이지가 없으면 nil → 바코드 대신 폴백 라인.
    /// 진행률 0~1. 전체 페이지 수를 알면 항상 값이 있고(0%부터), 모르면 nil.
    let progress: Double?
    let progressPercent: Int?

    /// 헤더 스트립 우측 날짜(최근 세션). 세션이 없으면 "아직 기록 없음".
    let headerDate: String

    /// 완독 여부. CTA 분기(완독이면 '여정보기' 하나)와 ⋮ 메뉴 라벨이 쓴다.
    let isFinished: Bool

    init(book: Book, calendar: Calendar = .current) {
        self.id = book.id
        self.title = book.displayTitle
        self.author = book.author
        self.coverURL = book.coverRemoteURL
        // 서재 카드색: 표지 대표색이 추출돼 있으면 그 색(은은한 톤), 없으면 book.id 해시 폴백.
        // (서재 한정 — 중앙 swatch(for:)는 그대로라 독서여정·지도·독서 화면은 해시 유지.)
        if let hex = book.coverColorHex, let value = UInt32(hex, radix: 16) {
            self.swatch = PassagePalette.coverSwatch(hex: value)
        } else {
            self.swatch = PassagePalette.swatch(for: book)
        }

        // 완료 세션(진행 중 제외)을 최신순으로.
        let allSessions: [ReadingSession] = book.sessions ?? []
        let completed: [ReadingSession] = allSessions
            .filter { $0.endDate != nil }
            .sorted { ($0.endDate ?? $0.startDate) > ($1.endDate ?? $1.startDate) }

        self.sessionCount = completed.count
        self.totalDuration = completed.reduce(0) { $0 + $1.duration }
        self.totalDurationText = completed.isEmpty ? "아직 기록 없음" : totalDuration.readableDuration

        self.recentJourneys = completed.prefix(2).map { session in
            PassJourney(
                id: session.id,
                place: Self.placeName(session),
                meta: Self.journeyMeta(session),
                date: Self.dateText(session.endDate ?? session.startDate, calendar: calendar)
            )
        }

        // 진행률: 완료 세션 중 최대 endPage / 전체 페이지 수.
        // 전체 페이지 수를 알면 항상 표시(0%부터). 모르면 nil → 카드에서 '전체 페이지 수 입력' 프롬프트.
        if let total = book.totalPageCount, total > 0 {
            let current = completed.compactMap(\.endPage).max() ?? 0
            let ratio = min(1, max(0, Double(current) / Double(total)))
            self.progress = ratio
            self.progressPercent = Int((ratio * 100).rounded())
        } else {
            self.progress = nil
            self.progressPercent = nil
        }

        self.headerDate = completed.first
            .map { Self.dateText($0.endDate ?? $0.startDate, calendar: calendar) }
            ?? "아직 기록 없음"

        self.isFinished = book.isFinished
    }

    /// 책 목록 → 패스 목록(서재는 dateAdded 역순 쿼리이므로 그대로 매핑).
    static func list(from books: [Book], calendar: Calendar = .current) -> [PassPresentation] {
        books.map { PassPresentation(book: $0, calendar: calendar) }
    }

    // MARK: 파생 헬퍼

    private static func placeName(_ session: ReadingSession) -> String {
        let name = session.place?.name ?? ""
        return name.isEmpty ? "장소 없음" : name
    }

    /// "45분 · 280p" — 그 여정에서 도달한 마지막 페이지(절대 위치). 시작 페이지 제안·진행률과 일관.
    private static func journeyMeta(_ session: ReadingSession) -> String {
        var parts = [session.duration.readableDuration]
        if let end = session.endPage {
            parts.append("\(end)p")
        }
        return parts.joined(separator: " · ")
    }

    /// "6월 22일 (일)" — 목업 포맷. DateFormatter(비 Sendable) 대신 캘린더 성분으로 직접 조립.
    private static func dateText(_ date: Date, calendar: Calendar) -> String {
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        let weekday = calendar.component(.weekday, from: date)   // 1 = 일요일
        let symbols = ["일", "월", "화", "수", "목", "금", "토"]
        let w = symbols[(weekday - 1 + 7) % 7]
        return "\(month)월 \(day)일 (\(w))"
    }
}
