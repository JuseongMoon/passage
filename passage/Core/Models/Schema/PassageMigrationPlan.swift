//
//  PassageMigrationPlan.swift
//  passage
//
//  스키마 마이그레이션 계획. 새 버전 추가 시 schemas와 stages를 확장한다.
//  대부분의 필드 추가는 .lightweight, 데이터 변환이 필요하면 .custom 사용.
//

import Foundation
import SwiftData

enum PassageMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self, SchemaV3.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2, migrateV2toV3]
    }

    /// V1→V2: Book.finishedDate 추가뿐 — 데이터 변환 없이 경량 마이그레이션.
    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: SchemaV1.self,
        toVersion: SchemaV2.self
    )

    /// V2→V3: Book.coverColorHex 추가뿐 — 데이터 변환 없이 경량 마이그레이션.
    static let migrateV2toV3 = MigrationStage.lightweight(
        fromVersion: SchemaV2.self,
        toVersion: SchemaV3.self
    )
}
