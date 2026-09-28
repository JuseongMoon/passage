//
//  PassageSchemaTests.swift
//  passageTests
//
//  스키마 버저닝 회귀 방지. (→ ARCHITECTURE §5, DECISIONS #31)
//  - 픽스처: 각 스키마 버전이 실제로 만든 온디스크 스토어. 새 코드가 옛 스토어를 데이터 손실 없이 여는지 본다.
//

import Testing
import SwiftData
import Foundation
import SQLite3
@testable import passage

@MainActor
struct PassageSchemaTests {

    // MARK: 옛 스토어 열기

    /// 버저닝 도입 전 코드가 만든 스토어(테스터 기기에 있는 것)를 데이터 손실 없이 연다.
    @Test func opensUnversionedStore() throws {
        let container = try Fixture.open("store-unversioned")   // 컨테이너를 보유해야 context가 살아 있다
        let context = container.mainContext

        let books = try context.fetch(FetchDescriptor<Book>())
        #expect(books.count == 2)
        let finished = try #require(books.first { $0.isFinished })
        #expect(finished.title == "소년이 온다")
        #expect(finished.subtitle == "한강 장편소설")
        #expect(finished.coverColorHex == "C08040")
        #expect(finished.sessions?.count == 3)
        #expect(finished.quotes?.first?.page == 88)

        let sessions = try context.fetch(FetchDescriptor<ReadingSession>())
        #expect(sessions.count == 4)
        #expect(sessions.filter(\.isActive).count == 1)
        #expect(Set(sessions.compactMap { $0.place?.name }) == ["동네 카페", "집"])

        let photos = try context.fetch(FetchDescriptor<SessionPhoto>())
        #expect(photos.count == 3)
        #expect(photos.allSatisfy { $0.data?.count == 256 && $0.session != nil })
    }

    // MARK: 버전 계획 불변식

    /// 두 버전이 같은 모델 클래스를 공유하면 체크섬이 같아져 "Duplicate version checksums"
    /// **잡을 수 없는 예외**로 런치가 죽는다(#22). 실행 전에 정적으로 막는다.
    @Test func versionsDoNotShareModelClasses() {
        var seen = Set<ObjectIdentifier>()
        for version in PassageMigrationPlan.schemas {
            for model in version.models {
                #expect(seen.insert(ObjectIdentifier(model)).inserted, "\(version)가 이전 버전과 \(model)을 공유한다")
            }
        }
    }

    /// 계획은 앱이 쓰는 버전에서 끝나고, 버전 번호는 겹치지 않으며, 인접 버전마다 단계가 하나씩 있다.
    @Test func planEndsAtLatestAndConnectsEveryVersion() throws {
        let schemas = PassageMigrationPlan.schemas
        let last = try #require(schemas.last)
        #expect(ObjectIdentifier(last) == ObjectIdentifier(PassageSchemaLatest.self))
        #expect(Set(schemas.map { "\($0.versionIdentifier)" }).count == schemas.count)
        #expect(PassageMigrationPlan.stages.count == schemas.count - 1)
    }

    // MARK: 픽스처 만들기

    /// 현재 스키마로 픽스처 스토어를 만든다. 새 스키마 버전을 추가하기 **전에** 한 번 실행해 둔다.
    /// `TEST_RUNNER_PASSAGE_WRITE_FIXTURE=<이름> xcodebuild test … '-only-testing:passageTests/PassageSchemaTests/writeFixture()'`
    @Test(.enabled(if: ProcessInfo.processInfo.environment["PASSAGE_WRITE_FIXTURE"] != nil))
    func writeFixture() throws {
        let name = try #require(ProcessInfo.processInfo.environment["PASSAGE_WRITE_FIXTURE"])
        let work = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        let storeURL = work.appending(path: "default.store")

        do {
            let container = try PassageModelContainer.makeContainer(
                ModelConfiguration(schema: PassageModelContainer.schema, url: storeURL, cloudKitDatabase: .none)
            )
            try Fixture.seed(container.mainContext)
        }

        // WAL까지 합쳐 단일 파일로 굳힌다(픽스처는 -shm/-wal 없이 한 파일).
        let output = Fixture.directory.appending(path: "\(name).store")
        try? FileManager.default.removeItem(at: output)
        try Fixture.vacuum(storeURL, into: output)
    }
}

/// 픽스처 데이터와 파일 도구.
@MainActor
enum Fixture {
    static let directory = URL(filePath: #filePath).deletingLastPathComponent().appending(path: "Fixtures")

    /// 실사용에 가까운 모양: 완독/읽는 중 책, 장소 공유, 진행 중 세션, 사진, 인용구.
    static func seed(_ context: ModelContext) throws {
        let base = Date(timeIntervalSince1970: 1_780_000_000)

        let finished = Book(title: "소년이 온다 (한강 장편소설)", author: "한강", totalPageCount: 216)
        finished.coverColorHex = "C08040"
        finished.finishedDate = base.addingTimeInterval(86_400 * 3)
        let reading = Book(title: "프로젝트 헤일메리", author: "앤디 위어", isbn: "9788925588735", totalPageCount: 696)

        let cafe = Place(name: "동네 카페", latitude: 37.5665, longitude: 126.9780, address: "서울 중구")
        let home = Place(name: "집")
        [finished, reading].forEach(context.insert)
        [cafe, home].forEach(context.insert)

        for i in 0..<3 {
            let session = ReadingSession(book: finished, startDate: base.addingTimeInterval(Double(i) * 86_400), startPage: i * 70 + 1)
            session.endDate = session.startDate.addingTimeInterval(1_800)
            session.duration = 1_800
            session.endPage = i * 70 + 70
            session.place = i == 2 ? home : cafe
            session.note = "세션 \(i + 1)의 생각"
            context.insert(session)
            context.insert(SessionPhoto(data: Data(repeating: UInt8(i + 1), count: 256), session: session))
        }
        let active = ReadingSession(book: reading, startDate: base.addingTimeInterval(86_400 * 4), startPage: 1)
        active.place = cafe
        context.insert(active)

        context.insert(Quote(text: "시간이 흘러도 잊히지 않는 문장.", page: 88, book: finished))
        try context.save()
    }

    /// 픽스처를 임시 폴더로 복사해 앱과 같은 경로(`makeContainer`)로 연다. 원본 픽스처는 건드리지 않는다.
    static func open(_ name: String) throws -> ModelContainer {
        let work = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        let storeURL = work.appending(path: "default.store")
        try FileManager.default.copyItem(at: directory.appending(path: "\(name).store"), to: storeURL)
        return try PassageModelContainer.makeContainer(
            ModelConfiguration(schema: PassageModelContainer.schema, url: storeURL, cloudKitDatabase: .none)
        )
    }

    static func vacuum(_ source: URL, into destination: URL) throws {
        var db: OpaquePointer?
        guard sqlite3_open_v2(source.path(percentEncoded: false), &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            throw FixtureError.sqlite(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_close(db) }
        let sql = "VACUUM INTO '\(destination.path(percentEncoded: false).replacingOccurrences(of: "'", with: "''"))'"
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
            throw FixtureError.sqlite(String(cString: sqlite3_errmsg(db)))
        }
    }

    enum FixtureError: Error { case sqlite(String) }
}
