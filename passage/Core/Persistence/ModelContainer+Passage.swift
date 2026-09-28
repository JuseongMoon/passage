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
//  ⚠️ 마이그레이션 실패 시 **기존 스토어를 지우고 새로 만든다**(3차 폴백 · DECISIONS #26). 지금 사용자는 전부
//  테스터라 데이터 보존보다 "언제나 켜지는 것"이 우선이라는 결정. 정식 출시 전에는 이 폴백을 제거해야 한다 —
//  안 그러면 실사용자 데이터가 조용히 날아간다. 버전 간 체크섬 중복(#22)은 잡을 수 없는 예외라 이 폴백으로도 못 막는다.
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
        //      스토어를 지우고 빈 상태로 다시 만든다 — 데이터는 사라지지만 앱은 켜진다.
        logger.error("기존 스토어를 열 수 없습니다 — 스토어를 삭제하고 새로 만듭니다(테스터 단계 정책).")
        destroyStore(at: localConfig.url)

        if let container = try? makeContainer(cloudConfig) {
            return container
        }
        do {
            return try makeContainer(localConfig)
        } catch {
            fatalError("ModelContainer 생성 실패(스토어 삭제 후에도): \(error)")
        }
    }

    /// SQLite 스토어와 그 저널 파일(-shm/-wal)을 함께 지운다. 셋 중 하나라도 남으면 다시 열지 못한다.
    private static func destroyStore(at url: URL) {
        let fileManager = FileManager.default
        for suffix in ["", "-shm", "-wal"] {
            let target = URL(fileURLWithPath: url.path(percentEncoded: false) + suffix)
            do {
                try fileManager.removeItem(at: target)
                logger.notice("스토어 파일 삭제: \(target.lastPathComponent, privacy: .public)")
            } catch CocoaError.fileNoSuchFile {
                continue      // 저널 파일은 없을 수 있다(정상)
            } catch {
                logger.error("스토어 파일 삭제 실패(\(target.lastPathComponent, privacy: .public)): \(error)")
            }
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
