//
//  PageCountTests.swift
//  passageTests
//
//  페이지 수 보조 조회: 알라딘 응답 파싱 + 조합(폴백) 로직 검증.
//

import Testing
import Foundation
@testable import passage

@MainActor
struct PageCountTests {

    private struct FixedProvider: PageCountService {
        let value: Int?
        func pageCount(isbn: String) async -> Int? { value }
    }

    // MARK: 알라딘 파싱

    @Test func aladinParsesItemPage() {
        let json = Data(#"{"item":[{"subInfo":{"itemPage":349}}]}"#.utf8)
        #expect(AladinPageCountService.parse(json) == 349)
    }

    @Test func aladinParseReturnsNilForMissingZeroOrGarbage() {
        #expect(AladinPageCountService.parse(Data(#"{"item":[{"subInfo":{}}]}"#.utf8)) == nil)
        #expect(AladinPageCountService.parse(Data(#"{"item":[{"subInfo":{"itemPage":0}}]}"#.utf8)) == nil)
        #expect(AladinPageCountService.parse(Data(#"{"item":[]}"#.utf8)) == nil)
        #expect(AladinPageCountService.parse(Data(#"{}"#.utf8)) == nil)
        #expect(AladinPageCountService.parse(Data("not json".utf8)) == nil)
    }

    // MARK: 조합(폴백)

    @Test func compositeReturnsFirstNonNil() async {
        let composite = CompositePageCountService(providers: [
            FixedProvider(value: nil),      // 알라딘 실패 가정
            FixedProvider(value: 320),      // Google Books 성공 가정
            FixedProvider(value: 999)       // 이후는 호출 안 됨
        ])
        #expect(await composite.pageCount(isbn: "9788954682152") == 320)
    }

    @Test func compositeReturnsNilWhenAllNil() async {
        let composite = CompositePageCountService(providers: [
            FixedProvider(value: nil),
            FixedProvider(value: nil)
        ])
        #expect(await composite.pageCount(isbn: "x") == nil)
    }
}
