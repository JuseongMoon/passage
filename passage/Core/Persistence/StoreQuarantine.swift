//
//  StoreQuarantine.swift
//  passage
//
//  열 수 없는 스토어를 지우지 않고 옮겨 두는 곳. (→ DECISIONS #32)
//  앱은 새 스토어로 켜지고(iCloud 동기화를 쓰던 기록은 CloudKit에서 다시 내려받는다),
//  원본은 `Application Support/StoreQuarantine/<시각>/`에 남아 이후 복구할 수 있다.
//

import Foundation

enum StoreQuarantine {
    /// 보관분은 최근 것만 남긴다 — 반복 실패가 저장 공간을 계속 먹지 않게.
    static let keepCount = 3

    static var defaultRoot: URL { .applicationSupportDirectory.appending(path: "StoreQuarantine") }

    /// 스토어와 그에 딸린 파일을 `root/<시각>/`으로 옮기고 그 폴더를 돌려준다.
    /// 딸린 파일: 저널(`-shm`·`-wal`) · 외부 저장 폴더(`.<이름>_SUPPORT`, 큰 사진 등).
    /// 하나라도 못 옮기면 던진다 — 남은 저널이 새 스토어에 섞이면 새 스토어도 망가진다.
    @discardableResult
    static func quarantine(storeAt storeURL: URL, into root: URL = defaultRoot, now: Date = .now) throws -> URL {
        let fileManager = FileManager.default
        let folder = try makeFolder(in: root, now: now)
        for item in companions(of: storeURL) where fileManager.fileExists(atPath: item.path(percentEncoded: false)) {
            try fileManager.moveItem(at: item, to: folder.appending(path: item.lastPathComponent))
        }
        prune(root)
        return folder
    }

    /// 스토어 본체 + 저널 + 외부 저장 폴더.
    static func companions(of storeURL: URL) -> [URL] {
        let directory = storeURL.deletingLastPathComponent()
        let name = storeURL.lastPathComponent
        let support = "." + storeURL.deletingPathExtension().lastPathComponent + "_SUPPORT"
        return [name, name + "-shm", name + "-wal", support].map { directory.appending(path: $0) }
    }

    /// 이름이 시각순으로 정렬되는 폴더(`20260928T025500Z`). 같은 초에 두 번이면 뒤에 번호를 붙인다.
    private static func makeFolder(in root: URL, now: Date) throws -> URL {
        let stamp = now.formatted(Date.ISO8601FormatStyle(dateSeparator: .omitted, timeSeparator: .omitted, timeZone: .gmt))
        var folder = root.appending(path: stamp)
        var suffix = 2
        while FileManager.default.fileExists(atPath: folder.path(percentEncoded: false)) {
            folder = root.appending(path: "\(stamp)-\(suffix)")
            suffix += 1
        }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    private static func prune(_ root: URL) {
        let fileManager = FileManager.default
        guard let folders = try? fileManager.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else { return }
        let sorted = folders.filter { !$0.lastPathComponent.hasPrefix(".") }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        for old in sorted.dropLast(keepCount) {
            try? fileManager.removeItem(at: old)
        }
    }
}
