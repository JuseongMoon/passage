//
//  BookJourney.swift
//  passage
//
//  한 책의 "독서 여정" — 완료 세션에서 파생한 지도 표시 값(총시간·완독 상태·장소 시퀀스).
//  전부 순수 계산이라 뷰에서 분리해 단위 테스트로 검증한다. (Session is Source of Truth)
//  Feature 격리를 위해 Library의 PassPresentation을 import하지 않고 Core 모델에서만 파생한다.
//

import Foundation

/// 여정의 한 지점 — 한 장소에서 그 책을 읽은 모든 세션을 합친 것.
struct JourneyStop: Identifiable, Hashable, Sendable {
    let id: UUID              // 장소 id
    let name: String
    let latitude: Double?
    let longitude: Double?
    let duration: TimeInterval   // 그 장소에서의 총 체류(독서)시간
    let firstVisit: Date         // 첫 방문 시각(여정 순서 정렬용)

    var hasCoordinate: Bool { latitude != nil && longitude != nil }
    /// 마커 캡션용 "1시간 20분".
    var durationText: String { duration.readableDuration }
}

/// 한 책을 나타내는 여정 카드/지도 값.
struct BookJourney: Identifiable, Hashable, Sendable {
    let id: UUID             // 책 id
    let title: String
    let author: String
    let coverURL: String?
    let swatch: PassagePalette.Swatch

    let isFinished: Bool
    let totalDuration: TimeInterval
    let totalDurationText: String
    let sessionCount: Int

    /// 그 책을 읽은 장소들(첫 방문 순). 지도 점선 경로가 이 순서로 연결된다.
    let stops: [JourneyStop]
    /// "N곳의 여정" — 서로 다른 장소 수.
    var distinctPlaceCount: Int { stops.count }

    init(book: Book) {
        self.id = book.id
        self.title = book.displayTitle
        self.author = book.author
        self.coverURL = book.coverRemoteURL
        // 서재 카드와 같은 색: 표지 대표색이 추출돼 있으면 그 색(은은한 톤), 없으면 book.id 해시 폴백.
        // (지도 마커·가로 갤러리가 서재 카드와 같은 색을 쓰도록 통일.)
        if let hex = book.coverColorHex, let value = UInt32(hex, radix: 16) {
            self.swatch = PassagePalette.coverSwatch(hex: value)
        } else {
            self.swatch = PassagePalette.swatch(for: book)
        }
        self.isFinished = book.isFinished

        // 완료 세션(진행 중 제외).
        let completed: [ReadingSession] = (book.sessions ?? []).filter { $0.endDate != nil }
        self.sessionCount = completed.count
        self.totalDuration = completed.reduce(0) { $0 + $1.duration }
        self.totalDurationText = completed.isEmpty ? "아직 기록 없음" : totalDuration.readableDuration

        self.stops = Self.makeStops(from: completed)
    }

    /// 완료 세션을 장소별로 묶어 첫 방문 순으로 정렬(중복 제거는 place.id 기준).
    private static func makeStops(from completed: [ReadingSession]) -> [JourneyStop] {
        // place.id → 누적. 최초 등장 순서를 보존하려고 순서 배열 + 딕셔너리를 함께 쓴다.
        var order: [UUID] = []
        var byPlace: [UUID: (place: Place, duration: TimeInterval, firstVisit: Date)] = [:]
        for session in completed {
            guard let place = session.place else { continue }   // 장소 없는 세션은 지도에 못 얹음
            if var acc = byPlace[place.id] {
                acc.duration += session.duration
                acc.firstVisit = min(acc.firstVisit, session.startDate)
                byPlace[place.id] = acc
            } else {
                order.append(place.id)
                byPlace[place.id] = (place, session.duration, session.startDate)
            }
        }
        return order
            .compactMap { byPlace[$0] }
            .map { entry in
                JourneyStop(
                    id: entry.place.id,
                    name: entry.place.name.isEmpty ? "장소 없음" : entry.place.name,
                    latitude: entry.place.latitude,
                    longitude: entry.place.longitude,
                    duration: entry.duration,
                    firstVisit: entry.firstVisit
                )
            }
            .sorted { $0.firstVisit < $1.firstVisit }
    }

    /// 책 목록 → 여정 목록. 완료 세션이 하나도 없는 책(아직 읽은 기억 없음)은 제외한다.
    static func list(from books: [Book]) -> [BookJourney] {
        books
            .map(BookJourney.init)
            .filter { $0.sessionCount > 0 }
    }
}

/// 독서여정 필터(전체/진행 중/완료).
enum JourneyFilter: String, CaseIterable, Identifiable, Sendable {
    case all, inProgress, finished

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: "전체"
        case .inProgress: "진행 중"
        case .finished: "완료"
        }
    }

    func matches(_ journey: BookJourney) -> Bool {
        switch self {
        case .all: true
        case .inProgress: !journey.isFinished
        case .finished: journey.isFinished
        }
    }

    /// 목록에서 이 필터에 해당하는 여정 수(캡슐의 "전체 5" 배지).
    func count(in journeys: [BookJourney]) -> Int {
        journeys.lazy.filter(matches).count
    }
}

/// 헤더 요약 — "N시간 동안 M권의 책을 K곳에서 읽었어요"(전체 누적, 좌표 유무 무관).
struct JourneySummary: Sendable, Equatable {
    let totalHours: Int
    let bookCount: Int
    let placeCount: Int

    init(books: [Book]) {
        let completed = books.flatMap { ($0.sessions ?? []).filter { $0.endDate != nil } }
        let total = completed.reduce(0) { $0 + $1.duration }
        self.totalHours = Int(total / 3600)

        var bookSeen = Set<UUID>(); var books = 0
        for session in completed where session.book != nil {
            if bookSeen.insert(session.book!.id).inserted { books += 1 }
        }
        self.bookCount = books

        var placeSeen = Set<UUID>(); var places = 0
        for session in completed where session.place != nil {
            if placeSeen.insert(session.place!.id).inserted { places += 1 }
        }
        self.placeCount = places
    }

    /// 기록이 있으면 요약 문장, 없으면 nil(빈 상태에서 미표시).
    var sentence: String {
        "\(totalHours)시간 동안 \(bookCount)권의 책을 \(placeCount)곳에서 읽었어요"
    }
}
