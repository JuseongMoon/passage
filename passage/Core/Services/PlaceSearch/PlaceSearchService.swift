//
//  PlaceSearchService.swift
//  passage
//
//  장소(POI) 키워드 검색 — Naver 지역 검색(openapi.naver.com/v1/search/local).
//  책 검색과 같은 "검색" 스코프라 NAVER_SEARCH 크리덴셜을 재사용한다.
//  좌표: 응답의 mapx/mapy는 WGS84 × 10^7 정수 → /1e7로 경도/위도. (실응답으로 확인)
//

import Foundation

struct PlaceSearchResult: Sendable, Identifiable, Hashable {
    var id: String { "\(name)|\(latitude)|\(longitude)" }
    let name: String
    let category: String?
    let roadAddress: String?
    let address: String?
    let latitude: Double
    let longitude: Double
}

protocol PlaceSearchService: Sendable {
    func search(query: String) async throws -> [PlaceSearchResult]
}

@MainActor
final class NaverPlaceSearchService: PlaceSearchService {
    private let clientID: String
    private let clientSecret: String
    private let session: URLSession

    init(session: URLSession = .shared) {
        clientID = Bundle.main.object(forInfoDictionaryKey: "NAVER_SEARCH_CLIENT_ID") as? String ?? ""
        clientSecret = Bundle.main.object(forInfoDictionaryKey: "NAVER_SEARCH_CLIENT_SECRET") as? String ?? ""
        self.session = session
    }

    func search(query: String) async throws -> [PlaceSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        guard !clientID.isEmpty, !clientSecret.isEmpty else { throw BookSearchError.missingCredentials }

        var components = URLComponents(string: "https://openapi.naver.com/v1/search/local.json")!
        components.queryItems = [
            .init(name: "query", value: trimmed),
            .init(name: "display", value: "10")
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

    /// 응답 데이터 → 장소 결과. (네트워크 없이 테스트 가능)
    static func parse(_ data: Data) -> [PlaceSearchResult] {
        guard let decoded = try? JSONDecoder().decode(NaverLocalResponse.self, from: data) else {
            return []
        }
        return decoded.items?.compactMap(\.placeSearchResult) ?? []
    }
}

// MARK: - Response DTOs

private struct NaverLocalResponse: Decodable {
    let items: [Item]?

    struct Item: Decodable {
        let title: String?
        let category: String?
        let address: String?
        let roadAddress: String?
        let mapx: String?          // Naver는 좌표를 문자열로 반환
        let mapy: String?

        var placeSearchResult: PlaceSearchResult? {
            let name = (title ?? "").strippedLocalHTML
            guard !name.isEmpty,
                  let mapx, let mapy,
                  let x = Double(mapx), let y = Double(mapy) else { return nil }
            return PlaceSearchResult(
                name: name,
                category: category,
                roadAddress: roadAddress,
                address: address,
                latitude: y / 1e7,
                longitude: x / 1e7
            )
        }
    }
}

private extension String {
    /// Naver 검색 결과의 <b> 하이라이트 태그 및 기본 HTML 엔티티 제거.
    var strippedLocalHTML: String {
        var text = replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        let entities = ["&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&#39;": "'", "&apos;": "'"]
        for (entity, char) in entities {
            text = text.replacingOccurrences(of: entity, with: char)
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
