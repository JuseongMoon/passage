//
//  ReflectionOrganizer.swift
//  passage
//
//  기간(연도)별 독서 기억을 모은다. 수치·경쟁이 아니라 "무엇과 함께했는가"를 조용히 되돌아보기 위함.
//  모든 것은 ReadingSession/Quote에서 파생. (Session is Source of Truth · Memory over Productivity)
//

import Foundation

struct ReflectionDigest {
    let year: Int
    let books: [Book]
    let quotes: [Quote]
    let places: [Place]
}

enum ReflectionOrganizer {
    /// 완료된(endDate 있는) 세션이 있는 연도들, 내림차순.
    static func availableYears(_ sessions: [ReadingSession], calendar: Calendar = .current) -> [Int] {
        let years = sessions.compactMap { session -> Int? in
            guard session.endDate != nil else { return nil }
            return calendar.component(.year, from: session.startDate)
        }
        return Array(Set(years)).sorted(by: >)
    }

    /// 해당 연도의 책·구절·장소(중복 제거, 시간순).
    static func digest(
        year: Int,
        sessions: [ReadingSession],
        quotes: [Quote],
        calendar: Calendar = .current
    ) -> ReflectionDigest {
        let yearSessions = sessions
            .filter { $0.endDate != nil && calendar.component(.year, from: $0.startDate) == year }
            .sorted { $0.startDate < $1.startDate }

        var bookSeen = Set<UUID>()
        var books: [Book] = []
        for session in yearSessions {
            if let book = session.book, bookSeen.insert(book.id).inserted {
                books.append(book)
            }
        }

        var placeSeen = Set<UUID>()
        var places: [Place] = []
        for session in yearSessions {
            if let place = session.place, placeSeen.insert(place.id).inserted {
                places.append(place)
            }
        }

        let yearQuotes = quotes
            .filter { calendar.component(.year, from: $0.dateCreated) == year }
            .sorted { $0.dateCreated > $1.dateCreated }

        return ReflectionDigest(year: year, books: books, quotes: yearQuotes, places: places)
    }
}
