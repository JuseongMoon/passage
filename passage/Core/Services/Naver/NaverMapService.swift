//
//  NaverMapService.swift
//  passage
//
//  좌표↔주소 지오코딩. Naver Cloud Platform Maps REST(maps.apigw.ntruss.com). (→ ARCHITECTURE §8)
//  키는 Info.plist(← Secrets.xcconfig)에서 읽는다. 지도 렌더링(NMFMapView)은 Phase 1c에서 추가.
//
//  ⚠️ 응답 DTO는 Naver 실제 스키마를 근사한 것으로, Phase 1c에서 실제 응답으로 검증/보정한다.
//

import Foundation

struct GeoResult: Sendable, Hashable {
    let address: String
    let latitude: Double
    let longitude: Double
}

enum GeocodingError: Error, Sendable {
    case missingCredentials
    case invalidResponse
    case notFound
}

protocol GeocodingService: Sendable {
    /// 좌표 → 주소. 장소 생성 시 주소 자동 채움에 사용.
    func reverseGeocode(latitude: Double, longitude: Double) async throws -> String
    /// 주소 → 좌표 후보들.
    func geocode(query: String) async throws -> [GeoResult]
}

// 모듈 기본 격리가 MainActor이므로 서비스도 MainActor로 통일한다.
// 지오코딩 응답은 작은 JSON이라 메인에서 디코딩해도 부담이 없고(네트워크 await는 메인을 블로킹하지 않음),
// actor로 분리하면 MainActor 격리된 응답 DTO와 경계 충돌이 생긴다.
@MainActor
final class NaverMapService: GeocodingService {
    private let clientID: String
    private let clientSecret: String
    private let session: URLSession

    init(session: URLSession = .shared) {
        clientID = Bundle.main.object(forInfoDictionaryKey: "NAVER_MAP_CLIENT_ID") as? String ?? ""
        clientSecret = Bundle.main.object(forInfoDictionaryKey: "NAVER_MAP_CLIENT_SECRET") as? String ?? ""
        self.session = session
    }

    func reverseGeocode(latitude: Double, longitude: Double) async throws -> String {
        try ensureCredentials()
        var comps = URLComponents(string: "https://maps.apigw.ntruss.com/map-reversegeocode/v2/gc")!
        comps.queryItems = [
            .init(name: "coords", value: "\(longitude),\(latitude)"),   // 경도,위도 순서 주의
            .init(name: "orders", value: "roadaddr,addr"),
            .init(name: "output", value: "json")
        ]
        let data = try await perform(comps.url!)
        let decoded = try JSONDecoder().decode(ReverseGeocodeResponse.self, from: data)
        guard let address = decoded.bestAddress else { throw GeocodingError.notFound }
        return address
    }

    func geocode(query: String) async throws -> [GeoResult] {
        try ensureCredentials()
        var comps = URLComponents(string: "https://maps.apigw.ntruss.com/map-geocode/v2/geocode")!
        comps.queryItems = [.init(name: "query", value: query)]
        let data = try await perform(comps.url!)
        let decoded = try JSONDecoder().decode(GeocodeResponse.self, from: data)
        return decoded.addresses?.compactMap(\.asGeoResult) ?? []
    }

    // MARK: - Private

    private func ensureCredentials() throws {
        guard !clientID.isEmpty, !clientSecret.isEmpty else { throw GeocodingError.missingCredentials }
    }

    private func perform(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.addValue(clientID, forHTTPHeaderField: "X-NCP-APIGW-API-KEY-ID")
        request.addValue(clientSecret, forHTTPHeaderField: "X-NCP-APIGW-API-KEY")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw GeocodingError.invalidResponse
        }
        return data
    }
}

// MARK: - Response DTOs (Naver 스키마 근사)

private struct ReverseGeocodeResponse: Decodable {
    let results: [RegionResult]?

    struct RegionResult: Decodable {
        let region: Region?
        let land: Land?
    }
    struct Region: Decodable {
        let area1: Area?
        let area2: Area?
        let area3: Area?
    }
    struct Area: Decodable { let name: String? }
    struct Land: Decodable {
        let name: String?           // 도로명
        let number1: String?
        let number2: String?
        let addition0: Addition?    // 건물명 등
    }
    struct Addition: Decodable { let value: String? }

    var bestAddress: String? {
        guard let r = results?.first else { return nil }
        var parts: [String] = []
        for name in [r.region?.area1?.name, r.region?.area2?.name, r.region?.area3?.name] {
            if let name, !name.isEmpty { parts.append(name) }
        }
        if let road = r.land?.name, !road.isEmpty { parts.append(road) }
        if let n1 = r.land?.number1, !n1.isEmpty {
            if let n2 = r.land?.number2, !n2.isEmpty {
                parts.append("\(n1)-\(n2)")
            } else {
                parts.append(n1)
            }
        }
        if let building = r.land?.addition0?.value, !building.isEmpty { parts.append(building) }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }
}

private struct GeocodeResponse: Decodable {
    let addresses: [Address]?

    struct Address: Decodable {
        let roadAddress: String?
        let jibunAddress: String?
        let x: String?      // 경도
        let y: String?      // 위도

        var asGeoResult: GeoResult? {
            guard let x, let y, let lon = Double(x), let lat = Double(y) else { return nil }
            let address = (roadAddress?.isEmpty == false ? roadAddress : jibunAddress) ?? ""
            return GeoResult(address: address, latitude: lat, longitude: lon)
        }
    }
}
