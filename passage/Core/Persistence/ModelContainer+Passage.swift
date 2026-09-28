//
//  ModelContainer+Passage.swift
//  passage
//
//  앱 ModelContainer 팩토리. CloudKit private DB로 동기화하되,
//  CloudKit이 불가한 환경(iCloud 미로그인 시뮬레이터 등)에서는 로컬로 폴백해 항상 실행되게 한다.
//
//  스키마 진화: 버전별 스냅샷(`PassageSchemaV<n>`) + `PassageMigrationPlan`. 모든 컨테이너는 `makeContainer(_:)`로
//  만들어 마이그레이션 계획이 빠진 경로가 없게 한다. (→ Schema/PassageSchema.swift · DECISIONS #31)
//
//  기존 스토어를 열 수 없으면(비-additive 스키마 변경·손상) **지우지 않고 격리 보관**한 뒤 새 스토어로 켠다(3차 폴백 ·
//  DECISIONS #32). 다음 화면에서 한 번 알린다. 버전 간 체크섬 중복(#22)은 잡을 수 없는 예외라 이 폴백으로도 못 막는다 —
//  `PassageSchemaTests`가 막는다.
//

import Foundation
import SwiftData
import OSLog

enum PassageModelContainer {
    private static let logger = Logger(subsystem: "com.ScienceFiction.passage", category: "Persistence")

    /// 현재 버전 스키마. 구성(`ModelConfiguration`)도 같은 스키마로 만든다.
    static var schema: Schema { Schema(versionedSchema: PassageSchemaLatest.self) }

    /// 모든 컨테이너의 단일 생성 지점 — 앱·프리뷰·테스트가 같은 마이그레이션 계획을 쓴다.
    static func makeContainer(_ configuration: ModelConfiguration) throws -> ModelContainer {
        try ModelContainer(for: schema, migrationPlan: PassageMigrationPlan.self, configurations: configuration)
    }

    /// 앱 기본 컨테이너.
    static func makeShared() -> ModelContainer {

        // 1차: CloudKit 동기화 구성(entitlement의 컨테이너를 자동 사용).
        let cloudConfig = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )
        if let container = try? makeContainer(cloudConfig) {
            return container
        }

        // 2차: 로컬 전용 폴백 — iCloud 미로그인 등 CloudKit만 불가한 환경을 위한 정상 경로.
        logger.warning("CloudKit 컨테이너 생성 실패 — 로컬 저장으로 폴백합니다.")
        let localConfig = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )
        if let container = try? makeContainer(localConfig) {
            return container
        }

        // 3차: 여기까지 왔으면 기존 스토어 자체를 열 수 없다(대개 비-additive 스키마 변경).
        //      원본은 격리 보관하고 빈 스토어로 다시 만든다 — 앱은 켜지고, 원본은 남는다.
        //      옮기지 못하면 지우지 않는다(아래 생성이 실패해 멈춘다). 이름 변경 수준의 이동이라 실패는 파일 시스템 이상뿐이다.
        logger.error("기존 스토어를 열 수 없습니다 — 원본을 격리 보관하고 새 스토어로 엽니다.")
        do {
            let folder = try StoreQuarantine.quarantine(storeAt: localConfig.url)
            logger.notice("스토어 격리 보관: \(folder.lastPathComponent, privacy: .public)")
            UserDefaults.standard.set(true, forKey: AppStorageKey.storeRecoveryNoticePending)
        } catch {
            logger.error("스토어 격리 보관 실패: \(error)")
        }

        if let container = try? makeContainer(cloudConfig) {
            return container
        }
        do {
            return try makeContainer(localConfig)
        } catch {
            fatalError("ModelContainer 생성 실패(스토어 격리 보관 후에도): \(error)")
        }
    }

    /// Preview·테스트용 인메모리 컨테이너.
    static func makePreview() -> ModelContainer {
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        do {
            return try makeContainer(config)
        } catch {
            fatalError("Preview ModelContainer 생성 실패: \(error)")
        }
    }
}
