//
//  ModelContainer+Passage.swift
//  passage
//
//  앱 ModelContainer 팩토리. CloudKit private DB로 동기화하되,
//  CloudKit이 불가한 환경(iCloud 미로그인 시뮬레이터 등)에서는 로컬로 폴백해 항상 실행되게 한다.
//

import Foundation
import SwiftData
import OSLog

enum PassageModelContainer {
    private static let logger = Logger(subsystem: "com.ScienceFiction.passage", category: "Persistence")

    /// 앱 기본 컨테이너.
    static func makeShared() -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)

        // 1차: CloudKit 동기화 구성(entitlement의 컨테이너를 자동 사용).
        let cloudConfig = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )
        if let container = try? ModelContainer(
            for: schema,
            migrationPlan: PassageMigrationPlan.self,
            configurations: cloudConfig
        ) {
            return container
        }

        // 2차: 로컬 전용 폴백.
        logger.warning("CloudKit 컨테이너 생성 실패 — 로컬 저장으로 폴백합니다.")
        let localConfig = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )
        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: PassageMigrationPlan.self,
                configurations: localConfig
            )
        } catch {
            fatalError("ModelContainer 생성 실패: \(error)")
        }
    }

    /// Preview·테스트용 인메모리 컨테이너.
    static func makePreview() -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("Preview ModelContainer 생성 실패: \(error)")
        }
    }
}
