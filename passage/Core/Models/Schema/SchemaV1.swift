//
//  SchemaV1.swift
//  passage
//
//  스키마 버전 1. 모델을 변경할 때는 SchemaV2를 추가하고
//  PassageMigrationPlan에 MigrationStage를 등록한다. (파괴적 변경 전 확인)
//

import Foundation
import SwiftData

enum SchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [Book.self, ReadingSession.self, Place.self]
    }
}
