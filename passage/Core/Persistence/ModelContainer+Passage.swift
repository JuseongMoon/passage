//
//  ModelContainer+Passage.swift
//  passage
//
//  앱 ModelContainer 팩토리. CloudKit private DB로 동기화하되,
//  CloudKit이 불가한 환경(iCloud 미로그인 시뮬레이터 등)에서는 로컬로 폴백해 항상 실행되게 한다.
//
//  스키마 진화: 지금까지의 변경은 전부 additive(옵셔널 필드 추가)라 **SwiftData 자동 lightweight 마이그레이션**에
//  맡긴다(migrationPlan 미지정). 과거의 VersionedSchema+MigrationPlan은 버전마다 모델 스냅샷 없이 같은 클래스를
//  가리켜 "Duplicate version checksums" 크래시를 유발했으므로 제거했다. (→ DECISIONS)
//
//  ⚠️ 마이그레이션 실패 시 **기존 스토어를 지우고 새로 만든다**(destroyAndRetry). 지금 사용자는 전부
//  테스터라 데이터 보존보다 "언제나 켜지는 것"이 우선이라는 결정. 정식 출시 전에는 이 폴백을 제거하고
//  버전별 스냅샷을 갖춘 VersionedSchema로 전환해야 한다 — 안 그러면 실사용자 데이터가 조용히 날아간다.
//

import Foundation
import SwiftData
import OSLog

enum PassageModelContainer {
    private static let logger = Logger(subsystem: "com.ScienceFiction.passage", category: "Persistence")

    private static var models: [any PersistentModel.Type] {
        [Book.self, ReadingSession.self, Place.self, Quote.self, SessionPhoto.self]
    }

    /// 앱 기본 컨테이너.
    static func makeShared() -> ModelContainer {
        let schema = Schema(models)

        // 1차: CloudKit 동기화 구성(entitlement의 컨테이너를 자동 사용).
        let cloudConfig = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )
        if let container = try? ModelContainer(for: schema, configurations: cloudConfig) {
            return container
        }

        // 2차: 로컬 전용 폴백 — iCloud 미로그인 등 CloudKit만 불가한 환경을 위한 정상 경로.
        logger.warning("CloudKit 컨테이너 생성 실패 — 로컬 저장으로 폴백합니다.")
        let localConfig = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )
        if let container = try? ModelContainer(for: schema, configurations: localConfig) {
            return container
        }

        // 3차: 여기까지 왔으면 기존 스토어 자체를 열 수 없다(대개 비-additive 스키마 변경).
        //      스토어를 지우고 빈 상태로 다시 만든다 — 데이터는 사라지지만 앱은 켜진다.
        logger.error("기존 스토어를 열 수 없습니다 — 스토어를 삭제하고 새로 만듭니다(테스터 단계 정책).")
        destroyStore(at: localConfig.url)

        if let container = try? ModelContainer(for: schema, configurations: cloudConfig) {
            return container
        }
        do {
            return try ModelContainer(for: schema, configurations: localConfig)
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
        let schema = Schema(models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("Preview ModelContainer 생성 실패: \(error)")
        }
    }
}
