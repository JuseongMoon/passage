//
//  ImageStore.swift
//  passage
//
//  사진 등 바이너리의 로컬 저장소 추상화. 참조 id만 SwiftData에 저장한다.
//  MVP는 LocalImageStore(파일). 후일 CloudImageStore로 교체 가능. (DECISIONS #9)
//

import Foundation

protocol ImageStore: Sendable {
    /// 데이터를 저장하고 참조 id를 반환한다.
    func save(_ data: Data) async throws -> String
    /// 참조 id로 데이터를 불러온다. 없으면 nil.
    func loadData(id: String) async throws -> Data?
    /// 참조 id의 데이터를 삭제한다.
    func delete(id: String) async throws
}

/// 파일 기반 로컬 구현. Application Support/PassageImages/ 에 저장.
actor LocalImageStore: ImageStore {
    private let directory: URL

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        directory = base.appending(path: "PassageImages", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func save(_ data: Data) async throws -> String {
        let id = UUID().uuidString
        try data.write(to: directory.appending(path: id), options: .atomic)
        return id
    }

    func loadData(id: String) async throws -> Data? {
        let url = directory.appending(path: id)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try Data(contentsOf: url)
    }

    func delete(id: String) async throws {
        let url = directory.appending(path: id)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }
}
