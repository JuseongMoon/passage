//
//  QuoteTests.swift
//  passageTests
//
//  인용구 저장 및 책 관계 검증 (스키마에 Quote 포함 여부도 함께 확인).
//

import Testing
import SwiftData
import Foundation
@testable import passage

@MainActor
struct QuoteTests {

    @Test func addQuoteToBook() throws {
        let container = PassageModelContainer.makePreview()
        let context = container.mainContext
        let book = Book(title: "데미안")
        context.insert(book)

        let quote = Quote(text: "새는 알에서 나오려고 투쟁한다.", page: 123, book: book)
        context.insert(quote)
        try context.save()

        let quotes = try context.fetch(FetchDescriptor<Quote>())
        #expect(quotes.count == 1)
        #expect(quotes.first?.text == "새는 알에서 나오려고 투쟁한다.")
        #expect(quotes.first?.page == 123)
        #expect(quotes.first?.book?.title == "데미안")
    }

    @Test func deletingBookCascadesQuotes() throws {
        let container = PassageModelContainer.makePreview()
        let context = container.mainContext
        let book = Book(title: "데미안")
        context.insert(book)
        context.insert(Quote(text: "구절", book: book))
        try context.save()

        context.delete(book)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<Quote>()).isEmpty)
    }
}
