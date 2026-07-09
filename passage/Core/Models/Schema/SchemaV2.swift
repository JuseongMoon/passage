//
//  SchemaV2.swift
//  passage
//
//  스키마 버전 2. V1에 Book.finishedDate(완독 표시)를 더한 것 외 구조는 동일.
//  필드 추가뿐이라 V1→V2는 .lightweight 마이그레이션. (→ PassageMigrationPlan)
//

import Foundation
import SwiftData

enum SchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [Book.self, ReadingSession.self, Place.self, Quote.self, PlacePhoto.self]
    }
}
