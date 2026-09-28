//
//  StoreQuarantineTests.swift
//  passageTests
//
//  열 수 없는 스토어는 지우지 않고 옮긴다 — 딸린 파일까지 빠짐없이, 보관분은 최근 것만. (→ DECISIONS #32)
//

import Testing
import Foundation
@testable import passage

@MainActor
struct StoreQuarantineTests {

    /// 본체·저널·외부 저장 폴더가 모두 한 폴더로 옮겨지고, 원래 자리는 비고, 내용은 그대로다.
    @Test func movesStoreWithAllCompanions() throws {
        let sandbox = try Sandbox()
        let store = sandbox.store
        try sandbox.write(store, "main")
        try sandbox.write(URL(filePath: store.path(percentEncoded: false) + "-shm"), "shm")
        try sandbox.write(URL(filePath: store.path(percentEncoded: false) + "-wal"), "wal")
        let support = sandbox.data.appending(path: ".default_SUPPORT/_EXTERNAL_DATA")
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        try sandbox.write(support.appending(path: "photo"), "photo-bytes")

        let folder = try StoreQuarantine.quarantine(storeAt: store, into: sandbox.root)

        for item in StoreQuarantine.companions(of: store) {
            #expect(!FileManager.default.fileExists(atPath: item.path(percentEncoded: false)), "\(item.lastPathComponent)이 남았다")
        }
        #expect(try String(contentsOf: folder.appending(path: "default.store"), encoding: .utf8) == "main")
        #expect(try String(contentsOf: folder.appending(path: "default.store-wal"), encoding: .utf8) == "wal")
        #expect(try String(contentsOf: folder.appending(path: ".default_SUPPORT/_EXTERNAL_DATA/photo"), encoding: .utf8) == "photo-bytes")
    }

    /// 저널이 없는 스토어(체크포인트 직후 등)도 문제없이 옮긴다.
    @Test func movesStoreWithoutJournals() throws {
        let sandbox = try Sandbox()
        try sandbox.write(sandbox.store, "main")

        let folder = try StoreQuarantine.quarantine(storeAt: sandbox.store, into: sandbox.root)

        #expect(FileManager.default.fileExists(atPath: folder.appending(path: "default.store").path(percentEncoded: false)))
        #expect(!FileManager.default.fileExists(atPath: sandbox.store.path(percentEncoded: false)))
    }

    /// 반복 실패해도 최근 `keepCount`개만 남는다. 같은 초에 두 번이어도 덮어쓰지 않는다.
    @Test func keepsOnlyRecentFolders() throws {
        let sandbox = try Sandbox()
        let base = Date(timeIntervalSince1970: 1_790_000_000)
        var made: [String] = []
        for offset in [0, 60, 120, 120, 180] {
            try sandbox.write(sandbox.store, "store \(offset)")
            made.append(try StoreQuarantine.quarantine(storeAt: sandbox.store, into: sandbox.root, now: base + Double(offset)).lastPathComponent)
        }

        let remaining = try FileManager.default.contentsOfDirectory(atPath: sandbox.root.path(percentEncoded: false)).sorted()
        #expect(Set(made).count == 5)
        #expect(remaining.count == StoreQuarantine.keepCount)
        #expect(remaining == Array(made.sorted().suffix(StoreQuarantine.keepCount)))
    }
}

/// 임시 폴더 안의 가짜 앱 데이터(`data/default.store`)와 보관 루트(`quarantine/`).
private struct Sandbox {
    let data: URL
    let root: URL
    var store: URL { data.appending(path: "default.store") }

    init() throws {
        let base = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        data = base.appending(path: "data")
        root = base.appending(path: "quarantine")
        try FileManager.default.createDirectory(at: data, withIntermediateDirectories: true)
    }

    func write(_ url: URL, _ text: String) throws {
        try text.write(to: url, atomically: true, encoding: .utf8)
    }
}
