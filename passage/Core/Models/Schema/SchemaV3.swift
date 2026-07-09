//
//  SchemaV3.swift
//  passage
//
//  스키마 버전 3. V2에 Book.coverColorHex(표지 대표색)를 더한 것 외 구조는 동일.
//  필드 추가뿐이라 V2→V3는 .lightweight 마이그레이션. (→ PassageMigrationPlan)
//

import Foundation
import SwiftData

enum SchemaV3: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(3, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [Book.self, ReadingSession.self, Place.self, Quote.self, PlacePhoto.self]
    }
}
