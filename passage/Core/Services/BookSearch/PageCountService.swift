//
//  PageCountService.swift
//  passage
//
//  ISBN으로 '전체 페이지 수'를 보조 조회한다. 네이버 책 검색은 페이지 수를 주지 않으므로(#13),
//  책 추가 시 이걸로 채워 독서 진행률 바코드를 자동 표시한다. (실패해도 수동 입력이 폴백)
//  1순위 알라딘(subInfo.itemPage) → 폴백 Google Books(volumeInfo.pageCount).
//

import Foundation

protocol PageCountService: Sendable {
    /// ISBN으로 전체 페이지 수를 조회. 없거나 실패하면 nil.
    func pageCount(isbn: String) async -> Int?
}

// MARK: - 알라딘 (1순위: 국내서 커버리지 우수, 깔끔한 정수)

/// 알라딘 Open API ItemLookUp의 `subInfo.itemPage`. TTBKey는 Info.plist(← Secrets.xcconfig).
struct AladinPageCountService: PageCountService {
    private let ttbKey: String?
    private let session: URLSession

    init(session: URLSession = .shared) {
        let key = Bundle.main.object(forInfoDictionaryKey: "ALADIN_TTB_KEY") as? String
        self.ttbKey = (key?.isEmpty == false) ? key : nil
        self.session = session
    }

    func pageCount(isbn: String) async -> Int? {
        guard let ttbKey else { return nil }          // 키 없으면 조용히 스킵 → 폴백/수동
        let digits = isbn.filter(\.isNumber)
        guard digits.count == 10 || digits.count == 13 else { return nil }

        var components = URLComponents(string: "https://www.aladin.co.kr/ttb/api/ItemLookUp.aspx")!
        components.queryItems = [
            .init(name: "ttbkey", value: ttbKey),
            .init(name: "itemIdType", value: digits.count == 13 ? "ISBN13" : "ISBN"),
            .init(name: "ItemId", value: digits),
            .init(name: "output", value: "js"),
            .init(name: "Version", value: "20131101"),
            .init(name: "Cover", value: "None")
        ]
        guard let url = components.url,
              let (data, response) = try? await session.data(from: url),
              let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode)
        else { return nil }
        return Self.parse(data)
    }

    /// 응답 → 페이지 수. (네트워크 없이 테스트)
    static func parse(_ data: Data) -> Int? {
        guard let decoded = try? JSONDecoder().decode(Response.self, from: data),
              let page = decoded.item?.first?.subInfo?.itemPage, page > 0
        else { return nil }
        return page
    }

    private struct Response: Decodable {
        let item: [Item]?
        struct Item: Decodable {
            let subInfo: SubInfo?
            struct SubInfo: Decodable { let itemPage: Int? }
        }
    }
}

// MARK: - Google Books (폴백: 기존 검색 서비스 재사용, volumeInfo.pageCount)

struct GoogleBooksPageCountService: PageCountService {
    let service: GoogleBooksSearchService

    func pageCount(isbn: String) async -> Int? {
        let result = try? await service.lookup(isbn: isbn)   // BookSearchResult??
        return (result ?? nil)?.pageCount.flatMap { $0 > 0 ? $0 : nil }
    }
}

// MARK: - 조합 (앞에서부터 첫 성공값)

struct CompositePageCountService: PageCountService {
    let providers: [any PageCountService]

    func pageCount(isbn: String) async -> Int? {
        for provider in providers {
            if let page = await provider.pageCount(isbn: isbn) { return page }
        }
        return nil
    }
}

// MARK: - Stub (프리뷰/테스트)

struct StubPageCountService: PageCountService {
    var fixed: Int?
    func pageCount(isbn: String) async -> Int? { fixed }
}
