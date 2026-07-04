//
//  NaverBookSearchService.swift
//  passage
//
//  Naver 책 검색(Naver Developers 검색 API). 무료 · 하루 25,000건. 한국 도서 메타데이터·표지 우수.
//  인증: developers.naver.com에서 발급한 Client ID/Secret을 헤더로. (지도용 Cloud Platform 키와 별개)
//  키는 Info.plist(← Secrets.xcconfig)의 NAVER_SEARCH_CLIENT_ID/SECRET에서 읽는다.
//

import Foundation

@MainActor
final class NaverBookSearchService: BookSearchService {
    private let clientID: String
    private let clientSecret: String
    private let session: URLSession

    init(session: URLSession = .shared) {
        clientID = Bundle.main.object(forInfoDictionaryKey: "NAVER_SEARCH_CLIENT_ID") as? String ?? ""
        clientSecret = Bundle.main.object(forInfoDictionaryKey: "NAVER_SEARCH_CLIENT_SECRET") as? String ?? ""
        self.session = session
    }

    func search(query: String) async throws -> [BookSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        guard !clientID.isEmpty, !clientSecret.isEmpty else { throw BookSearchError.missingCredentials }

        var components = URLComponents(string: "https://openapi.naver.com/v1/search/book.json")!
        components.queryItems = [
            .init(name: "query", value: trimmed),
            .init(name: "display", value: "20")
        ]
        var request = URLRequest(url: components.url!)
        request.addValue(clientID, forHTTPHeaderField: "X-Naver-Client-Id")
        request.addValue(clientSecret, forHTTPHeaderField: "X-Naver-Client-Secret")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw BookSearchError.invalidResponse
        }
        return Self.parse(data)
    }

    func lookup(isbn: String) async throws -> BookSearchResult? {
        try await search(query: isbn).first
    }

    /// 응답 데이터 → 검색 결과. (네트워크 없이 테스트 가능)
    static func parse(_ data: Data) -> [BookSearchResult] {
        guard let decoded = try? JSONDecoder().decode(NaverBookResponse.self, from: data) else {
            return []
        }
        return decoded.items?.compactMap(\.bookSearchResult) ?? []
    }
}

// MARK: - Response DTOs

private struct NaverBookResponse: Decodable {
    let items: [Item]?

    struct Item: Decodable {
        let title: String?
        let author: String?
        let isbn: String?
        let image: String?

        var bookSearchResult: BookSearchResult? {
            let cleanTitle = (title ?? "").strippedBookHTML
            guard !cleanTitle.isEmpty else { return nil }
            // 공저는 ^ 또는 | 로 구분되어 옴 → ", "로.
            let cleanAuthor = (author ?? "").strippedBookHTML
                .replacingOccurrences(of: "^", with: ", ")
                .replacingOccurrences(of: "|", with: ", ")
            // isbn 필드는 "ISBN10 ISBN13"(구) 또는 "ISBN13"(신) → 13자리 우선.
            let parts = (isbn ?? "").split(separator: " ").map(String.init)
            let isbn13 = parts.first { $0.count == 13 } ?? parts.last
            let cover = image.flatMap { $0.isEmpty ? nil : $0 }
            return BookSearchResult(
                title: cleanTitle,
                author: cleanAuthor,
                isbn: isbn13,
                coverURL: cover,
                pageCount: nil   // Naver 책 검색은 페이지 수를 제공하지 않음
            )
        }
    }
}

private extension String {
    /// Naver 검색 결과의 <b> 하이라이트 태그 및 기본 HTML 엔티티 제거.
    var strippedBookHTML: String {
        var text = replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        let entities = ["&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&#39;": "'", "&apos;": "'"]
        for (entity, char) in entities {
            text = text.replacingOccurrences(of: entity, with: char)
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
