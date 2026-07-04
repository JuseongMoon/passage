//
//  GoogleBooksSearchService.swift
//  passage
//
//  Google Books API로 책 검색/ISBN 조회. 키 불필요(경량 호출). (DECISIONS #13)
//  응답 파싱은 static parse로 분리해 네트워크 없이 테스트 가능하게 한다.
//

import Foundation

enum BookSearchError: Error, Sendable {
    case invalidResponse
}

@MainActor
final class GoogleBooksSearchService: BookSearchService {
    private let session: URLSession
    /// Info.plist(← Secrets.xcconfig)의 GOOGLE_BOOKS_API_KEY. 없으면 키 없이 호출(공용 할당량이라 불안정).
    private let apiKey: String?

    init(session: URLSession = .shared) {
        self.session = session
        let key = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_BOOKS_API_KEY") as? String
        self.apiKey = (key?.isEmpty == false) ? key : nil
    }

    func search(query: String) async throws -> [BookSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var components = URLComponents(string: "https://www.googleapis.com/books/v1/volumes")!
        components.queryItems = [
            .init(name: "q", value: trimmed),
            .init(name: "maxResults", value: "20")
        ]
        if let apiKey {
            components.queryItems?.append(.init(name: "key", value: apiKey))
        }
        let (data, response) = try await session.data(from: components.url!)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw BookSearchError.invalidResponse
        }
        return Self.parse(data)
    }

    func lookup(isbn: String) async throws -> BookSearchResult? {
        try await search(query: "isbn:\(isbn)").first
    }

    /// 응답 데이터 → 검색 결과. (테스트용으로 분리)
    static func parse(_ data: Data) -> [BookSearchResult] {
        guard let decoded = try? JSONDecoder().decode(GoogleBooksResponse.self, from: data) else {
            return []
        }
        return decoded.items?.compactMap(\.bookSearchResult) ?? []
    }
}

// MARK: - Response DTOs

private struct GoogleBooksResponse: Decodable {
    let items: [Item]?

    struct Item: Decodable {
        let volumeInfo: VolumeInfo?

        var bookSearchResult: BookSearchResult? {
            guard let info = volumeInfo, let title = info.title, !title.isEmpty else { return nil }
            let author = info.authors?.joined(separator: ", ") ?? ""
            let isbn = info.industryIdentifiers?.first { $0.type == "ISBN_13" }?.identifier
                ?? info.industryIdentifiers?.first?.identifier
            // Google 표지 URL은 http로 오는 경우가 많아 https로 승격(ATS)
            let cover = info.imageLinks?.thumbnail?.replacingOccurrences(of: "http://", with: "https://")
            return BookSearchResult(
                title: title,
                author: author,
                isbn: isbn,
                coverURL: cover,
                pageCount: info.pageCount
            )
        }
    }

    struct VolumeInfo: Decodable {
        let title: String?
        let authors: [String]?
        let pageCount: Int?
        let industryIdentifiers: [IndustryIdentifier]?
        let imageLinks: ImageLinks?
    }
    struct IndustryIdentifier: Decodable {
        let type: String?
        let identifier: String?
    }
    struct ImageLinks: Decodable {
        let thumbnail: String?
    }
}
