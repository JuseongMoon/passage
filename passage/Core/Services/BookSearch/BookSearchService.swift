//
//  BookSearchService.swift
//  passage
//
//  책 검색/ISBN 조회 추상화. MVP 구현은 Phase 1에서 Google Books(키 불필요)로. (DECISIONS #13)
//  수동 등록은 항상 가능한 오프라인 경로다.
//

import Foundation

struct BookSearchResult: Sendable, Identifiable, Hashable {
    var id: String { isbn ?? "\(title)|\(author)" }
    let title: String
    let author: String
    let isbn: String?
    let coverURL: String?
    let pageCount: Int?
}

protocol BookSearchService: Sendable {
    func search(query: String) async throws -> [BookSearchResult]
    func lookup(isbn: String) async throws -> BookSearchResult?
}

enum BookSearchError: Error, Sendable {
    case missingCredentials
    case invalidResponse
}

/// Phase 0 스텁: 실제 검색은 Phase 1에서 구현.
struct StubBookSearchService: BookSearchService {
    func search(query: String) async throws -> [BookSearchResult] { [] }
    func lookup(isbn: String) async throws -> BookSearchResult? { nil }
}
