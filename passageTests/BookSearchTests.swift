//
//  BookSearchTests.swift
//  passageTests
//
//  Google Books 응답 파싱 검증(네트워크 없이).
//

import Testing
import Foundation
@testable import passage

@MainActor
struct BookSearchTests {

    @Test func parsesGoogleBooksResponse() {
        let json = Data("""
        {
          "items": [
            {
              "volumeInfo": {
                "title": "데미안",
                "authors": ["헤르만 헤세"],
                "pageCount": 240,
                "industryIdentifiers": [
                  {"type": "ISBN_10", "identifier": "8937460440"},
                  {"type": "ISBN_13", "identifier": "9788937460449"}
                ],
                "imageLinks": {"thumbnail": "http://books.google.com/cover.jpg"}
              }
            }
          ]
        }
        """.utf8)

        let results = GoogleBooksSearchService.parse(json)
        #expect(results.count == 1)
        let book = results.first
        #expect(book?.title == "데미안")
        #expect(book?.author == "헤르만 헤세")
        #expect(book?.isbn == "9788937460449")           // ISBN_13 우선
        #expect(book?.pageCount == 240)
        #expect(book?.coverURL == "https://books.google.com/cover.jpg")  // http→https 승격
    }

    @Test func skipsItemsWithoutTitle() {
        let json = Data("""
        { "items": [ { "volumeInfo": { "authors": ["작자 미상"] } } ] }
        """.utf8)
        #expect(GoogleBooksSearchService.parse(json).isEmpty)
    }

    @Test func emptyOnGarbage() {
        #expect(GoogleBooksSearchService.parse(Data("not json".utf8)).isEmpty)
    }
}
