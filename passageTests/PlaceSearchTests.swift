//
//  PlaceSearchTests.swift
//  passageTests
//
//  Naver 지역 검색 파싱·좌표 변환 검증(네트워크 없이). 값은 실응답 기반.
//

import Testing
import Foundation
@testable import passage

@MainActor
struct PlaceSearchTests {

    @Test func parsesAndConvertsCoordinates() {
        let json = Data("""
        {
          "items": [
            {
              "title": "<b>스타벅스</b> 강남R점",
              "category": "카페,디저트>카페",
              "address": "서울특별시 강남구 역삼동",
              "roadAddress": "서울특별시 강남구 강남대로 390",
              "mapx": "1270284390",
              "mapy": "374977110"
            }
          ]
        }
        """.utf8)

        let results = NaverPlaceSearchService.parse(json)
        #expect(results.count == 1)
        let place = results.first
        #expect(place?.name == "스타벅스 강남R점")                    // <b> 제거
        #expect(place?.roadAddress == "서울특별시 강남구 강남대로 390")
        #expect(abs((place?.longitude ?? 0) - 127.028439) < 1e-6)     // mapx / 1e7
        #expect(abs((place?.latitude ?? 0) - 37.497711) < 1e-6)       // mapy / 1e7
    }

    @Test func skipsItemsWithoutCoordinates() {
        let json = Data("""
        { "items": [ { "title": "이름만 있고 좌표 없음", "mapx": "", "mapy": "" } ] }
        """.utf8)
        #expect(NaverPlaceSearchService.parse(json).isEmpty)
    }

    @Test func emptyOnGarbage() {
        #expect(NaverPlaceSearchService.parse(Data("not json".utf8)).isEmpty)
    }
}
