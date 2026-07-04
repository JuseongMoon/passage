//
//  NaverBookSearchTests.swift
//  passageTests
//
//  Naver 책 검색 응답 파싱 검증(네트워크 없이): HTML 태그 제거·공저 구분·ISBN13 추출.
//

import Testing
import Foundation
@testable import passage

@MainActor
struct NaverBookSearchTests {

    @Test func parsesNaverResponse() {
        let json = Data("""
        {
          "items": [
            {
              "title": "<b>데미안</b> (열린책들 세계문학 233)",
              "author": "헤르만 헤세^전영애",
              "isbn": "8932917248 9788932917245",
              "image": "https://bookthumb-phinf.pstatic.net/cover/demian.jpg"
            }
          ]
        }
        """.utf8)

        let results = NaverBookSearchService.parse(json)
        #expect(results.count == 1)
        let book = results.first
        #expect(book?.title == "데미안 (열린책들 세계문학 233)")   // <b> 제거
        #expect(book?.author == "헤르만 헤세, 전영애")             // ^ → ", "
        #expect(book?.isbn == "9788932917245")                    // ISBN13 우선
        #expect(book?.coverURL == "https://bookthumb-phinf.pstatic.net/cover/demian.jpg")
        #expect(book?.pageCount == nil)
    }

    @Test func decodesHTMLEntities() {
        let json = Data("""
        { "items": [ { "title": "Tom &amp; Jerry", "author": "작자", "isbn": "9791234567890" } ] }
        """.utf8)
        #expect(NaverBookSearchService.parse(json).first?.title == "Tom & Jerry")
    }

    @Test func emptyOnGarbage() {
        #expect(NaverBookSearchService.parse(Data("not json".utf8)).isEmpty)
    }
}
