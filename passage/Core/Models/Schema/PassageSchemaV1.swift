//
//  PassageSchemaV1.swift
//  passage
//
//  스키마 V1 스냅샷 — 버저닝 도입 전 스토어와 같은 스키마(체크섬 동일)라 기존 스토어를 그대로 연다.
//  스냅샷에는 **저장 속성·관계·속성 옵션과 인자 없는 `init()`만** 둔다. 동작은 `Core/Models/`의
//  typealias extension에 있다 — 새 버전을 만들 때 이 파일을 복사해도 동작이 따라가지 않게. (→ PassageSchema.swift)
//
//  nonisolated: 모듈 기본 격리가 MainActor여도 SwiftData가 내부 스레드에서 모델에 접근할 수 있어야 한다.
//  CloudKit 규칙: 모든 저장 속성은 optional 또는 기본값. `@Attribute(.unique)` 금지. 관계는 optional + inverse 필수.
//

import Foundation
import SwiftData

nonisolated enum PassageSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [Book.self, ReadingSession.self, Place.self, Quote.self, SessionPhoto.self]
    }

    /// 읽는 대상. (→ Book.swift)
    @Model
    nonisolated final class Book {
        var id: UUID = UUID()
        var title: String = ""
        /// 제목 괄호 부제 — 검색 제목의 첫 '(' 이후를 부제로 떼어 보관(현재 화면 미표시, 향후 사용). 괄호 없으면 "".
        var subtitle: String = ""
        var author: String = ""
        var isbn: String?
        var totalPageCount: Int?
        var coverRemoteURL: String?        // 검색 API가 준 표지 URL
        var coverImageRef: String?         // 로컬 ImageStore 참조(표지 캐시)
        var coverColorHex: String?         // 표지 대표색 "RRGGBB"(서재 카드색 소스). 미추출/표지없음이면 nil → 해시 폴백.
        var dateAdded: Date = Date()
        var finishedDate: Date?            // 완독 표시(다 읽은 날). nil = 읽는 중.

        // 책 삭제 시 그 책의 세션(기억)도 함께 삭제.
        @Relationship(deleteRule: .cascade, inverse: \ReadingSession.book)
        var sessions: [ReadingSession]? = []

        // 이 책에서 남긴 인용구. 책 삭제 시 함께 삭제.
        @Relationship(deleteRule: .cascade, inverse: \Quote.book)
        var quotes: [Quote]? = []

        init() {}
    }

    /// 한 번의 독서 행위. 앱의 원자 단위이자 Source of Truth. (→ ReadingSession.swift)
    @Model
    nonisolated final class ReadingSession {
        var id: UUID = UUID()
        var startDate: Date = Date()
        var endDate: Date?                  // nil == 진행 중
        var duration: TimeInterval = 0      // 종료 시 확정(일시정지 등 확장 대비해 계산값을 저장)
        var startPage: Int?
        var endPage: Int?
        var note: String?                   // 세션 회고 한 줄

        // to-one 관계(inverse는 Book/Place 쪽 to-many에서 선언).
        var book: Book?
        var place: Place?

        // 이 세션에서 남긴 사진. externalStorage(→ CloudKit CKAsset 자동 동기화). 세션 삭제 시 함께 삭제.
        @Relationship(deleteRule: .cascade, inverse: \SessionPhoto.session)
        var photos: [SessionPhoto]? = []

        init() {}
    }

    /// 읽은 곳. (→ Place.swift)
    @Model
    nonisolated final class Place {
        var id: UUID = UUID()
        var name: String = ""
        var latitude: Double?
        var longitude: Double?
        var address: String?
        var dateCreated: Date = Date()

        // 장소 삭제 시 세션의 place만 nullify(기억은 남고 장소만 사라짐).
        @Relationship(deleteRule: .nullify, inverse: \ReadingSession.place)
        var sessions: [ReadingSession]? = []

        init() {}
    }

    /// 책에서 남긴 인용구. (→ Quote.swift)
    @Model
    nonisolated final class Quote {
        var id: UUID = UUID()
        var text: String = ""
        var page: Int?
        var dateCreated: Date = Date()

        var book: Book?

        init() {}
    }

    /// 한 세션에서 남긴 사진. 바이너리는 externalStorage → CloudKit CKAsset. (→ SessionPhoto.swift)
    @Model
    nonisolated final class SessionPhoto {
        var id: UUID = UUID()
        @Attribute(.externalStorage) var data: Data?
        var dateAdded: Date = Date()

        var session: ReadingSession?

        init() {}
    }
}
