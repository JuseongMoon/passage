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
        [SchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []   // 예: [migrateV1toV2] — V2 도입 시 추가
    }
}
