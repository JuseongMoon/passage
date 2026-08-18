//
//  PassPresentationTests.swift
//  passageTests
//
//  서재 "패스" 표시값의 파생 로직 검증(진행률·최근 여정·총시간·색 안정성).
//  Session is Source of Truth — 전부 세션에서 계산된다.
//

import Testing
import SwiftData
import Foundation
import SwiftUI
@testable import passage

@MainActor
struct PassPresentationTests {

    @discardableResult
    private func finished(
        book: Book,
        start: Int?,
        end: Int?,
        duration: TimeInterval,
        endDate: Date,
        place: Place? = nil,
        in context: ModelContext
    ) -> ReadingSession {
        let session = ReadingSession(book: book, startPage: start)
        session.endPage = end
        session.duration = duration
        session.endDate = endDate
        session.place = place
        context.insert(session)
        return session
    }

    // MARK: 진행률

    @Test func progressFromMaxEndPageOverTotal() throws {
        let container = PassageModelContainer.makePreview()
        let context = container.mainContext
        let book = Book(title: "책", totalPageCount: 200)
        context.insert(book)
        finished(book: book, start: 0, end: 40, duration: 600, endDate: Date(timeIntervalSince1970: 1000), in: context)
        finished(book: book, start: 40, end: 120, duration: 1200, endDate: Date(timeIntervalSince1970: 2000), in: context)
        try context.save()

        let pass = PassPresentation(book: book)
        #expect(pass.progress == 0.6)          // 120 / 200
        #expect(pass.progressPercent == 60)
    }

    @Test func progressClampsAtOne() throws {
        let container = PassageModelContainer.makePreview()
        let context = container.mainContext
        let book = Book(title: "책", totalPageCount: 100)
        context.insert(book)
        finished(book: book, start: 0, end: 130, duration: 600, endDate: Date(timeIntervalSince1970: 1000), in: context)
        try context.save()

        let pass = PassPresentation(book: book)
        #expect(pass.progress == 1.0)
        #expect(pass.progressPercent == 100)
    }

    @Test func progressNilWhenNoPageCount() throws {
        let container = PassageModelContainer.makePreview()
        let context = container.mainContext
        let book = Book(title: "책")            // totalPageCount == nil
        context.insert(book)
        finished(book: book, start: 0, end: 40, duration: 600, endDate: Date(timeIntervalSince1970: 1000), in: context)
        try context.save()

        let pass = PassPresentation(book: book)
        #expect(pass.progress == nil)           // 전체 페이지 수 모르면 진행률 없음(카드에서 입력 프롬프트)
        #expect(pass.progressPercent == nil)
    }

    @Test func pageCountKnownButUnreadShowsZeroProgress() throws {
        let container = PassageModelContainer.makePreview()
        let context = container.mainContext
        let book = Book(title: "책", totalPageCount: 200)   // 페이지 수는 알지만 아직 안 읽음
        context.insert(book)
        try context.save()

        let pass = PassPresentation(book: book)
        #expect(pass.progress == 0.0)           // 0%부터 바코드 표시
        #expect(pass.progressPercent == 0)
        #expect(pass.totalDurationText == "아직 기록 없음")
        #expect(pass.headerDate == "아직 기록 없음")
        #expect(pass.recentJourneys.isEmpty)
    }

    // MARK: 총 독서시간 (활성 세션 제외)

    @Test func totalDurationSumsOnlyFinished() throws {
        let container = PassageModelContainer.makePreview()
        let context = container.mainContext
        let book = Book(title: "책")
        context.insert(book)
        finished(book: book, start: 0, end: 40, duration: 600, endDate: Date(timeIntervalSince1970: 1000), in: context)
        finished(book: book, start: 40, end: 90, duration: 1200, endDate: Date(timeIntervalSince1970: 2000), in: context)
        // 진행 중(endDate == nil) — 합계에서 제외되어야 한다.
        let active = ReadingSession(book: book, startPage: 90)
        context.insert(active)
        try context.save()

        let pass = PassPresentation(book: book)
        #expect(pass.totalDuration == 1800)
        #expect(pass.sessionCount == 2)
    }

    // MARK: 최근 여정기록

    @Test func recentJourneysMostRecentFirstMaxTwo() throws {
        let container = PassageModelContainer.makePreview()
        let context = container.mainContext
        let book = Book(title: "책")
        let cafe = Place(name: "동네 카페")
        let home = Place(name: "집")
        context.insert(book); context.insert(cafe); context.insert(home)
        finished(book: book, start: 0, end: 10, duration: 300, endDate: Date(timeIntervalSince1970: 1000), place: home, in: context)
        finished(book: book, start: 10, end: 30, duration: 600, endDate: Date(timeIntervalSince1970: 2000), place: cafe, in: context)
        finished(book: book, start: 30, end: 55, duration: 900, endDate: Date(timeIntervalSince1970: 3000), place: home, in: context)
        try context.save()

        let pass = PassPresentation(book: book)
        #expect(pass.recentJourneys.count == 2)                 // 최대 2개
        #expect(pass.recentJourneys[0].place == "집")            // 가장 최근(3000)
        #expect(pass.recentJourneys[1].place == "동네 카페")      // 그 다음(2000)
        #expect(pass.recentJourneys[0].meta == "15분 · 55p")    // 900초=15분, 도달 페이지 55p
    }

    @Test func journeyMetaOmitsPagesWhenMissing() throws {
        let container = PassageModelContainer.makePreview()
        let context = container.mainContext
        let book = Book(title: "책")
        context.insert(book)
        finished(book: book, start: nil, end: nil, duration: 300, endDate: Date(timeIntervalSince1970: 1000), in: context)
        try context.save()

        let pass = PassPresentation(book: book)
        #expect(pass.recentJourneys.first?.meta == "5분")       // 페이지 없으면 시간만
        #expect(pass.recentJourneys.first?.place == "장소 없음")   // 장소 없으면 폴백
    }

    @Test func headerDateKoreanFormat() throws {
        let container = PassageModelContainer.makePreview()
        let context = container.mainContext
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let date = calendar.date(from: DateComponents(year: 2026, month: 6, day: 22))!
        let book = Book(title: "책")
        context.insert(book)
        finished(book: book, start: 0, end: 10, duration: 300, endDate: date, in: context)
        try context.save()

        let pass = PassPresentation(book: book, calendar: calendar)
        #expect(pass.headerDate.hasPrefix("6월 22일 ("))
        #expect(pass.headerDate.hasSuffix(")"))
    }

    // MARK: 색 배정 안정성

    @Test func swatchIndexIsDeterministicAndInRange() {
        let id = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let first = PassagePalette.swatchIndex(for: id)
        let second = PassagePalette.swatchIndex(for: id)
        #expect(first == second)                                        // 재계산 시 동일
        #expect((0..<PassagePalette.swatches.count).contains(first))    // 범위 내
    }

    @Test func swatchForBookMatchesIndex() {
        let book = Book(title: "책")
        let expected = PassagePalette.swatches[PassagePalette.swatchIndex(for: book.id)]
        #expect(PassagePalette.swatch(for: book) == expected)
    }

    // MARK: 표지 대표색 → 서재 카드색

    @Test func presentationUsesCoverColorWhenPresent() {
        let book = Book(title: "책")
        book.coverColorHex = "E0A040"                       // 앰버
        #expect(PassPresentation(book: book).swatch == PassagePalette.coverSwatch(hex: 0xE0A040))
    }

    @Test func presentationFallsBackToHashWhenNoCoverColor() {
        let book = Book(title: "책")                        // coverColorHex == nil
        #expect(PassPresentation(book: book).swatch == PassagePalette.swatch(for: book))
    }

    // MARK: 완독 상태(CTA 분기·메뉴 라벨의 근거)

    @Test func isFinishedReflectsBookFinishedDate() throws {
        let container = PassageModelContainer.makePreview()
        let context = container.mainContext
        let book = Book(title: "작별하지 않는다", author: "한강")
        context.insert(book)

        #expect(PassPresentation(book: book).isFinished == false)

        book.finishedDate = .now
        #expect(PassPresentation(book: book).isFinished == true)

        book.finishedDate = nil          // 되돌리면 다시 읽는 중
        #expect(PassPresentation(book: book).isFinished == false)
    }

    /// CTA 분기의 근거: 기록이 하나도 없으면 여정보기를 열어 줄 수 없다
    /// (`BookJourney.list`가 완료 세션 없는 책을 제외하므로 빈 지도로 떨어진다).
    @Test func sessionCountIsZeroUntilASessionCompletes() throws {
        let container = PassageModelContainer.makePreview()
        let context = container.mainContext
        let book = Book(title: "데미안", totalPageCount: 240)
        context.insert(book)

        #expect(PassPresentation(book: book).sessionCount == 0)

        let running = ReadingSession(book: book, startPage: 1)   // 진행 중(endDate 없음)
        context.insert(running)
        #expect(PassPresentation(book: book).sessionCount == 0)

        finished(book: book, start: 1, end: 30, duration: 600, endDate: .now, in: context)
        #expect(PassPresentation(book: book).sessionCount == 1)
    }

    /// 완독 여부는 페이지 진행률과 독립이다 — 100%를 읽어도 표시하지 않으면 읽는 중이다.
    @Test func isFinishedIsIndependentOfProgress() throws {
        let container = PassageModelContainer.makePreview()
        let context = container.mainContext
        let book = Book(title: "채식주의자", totalPageCount: 200)
        context.insert(book)
        finished(book: book, start: 1, end: 200, duration: 3600, endDate: .now, in: context)

        let pass = PassPresentation(book: book)
        #expect(pass.progressPercent == 100)
        #expect(pass.isFinished == false)
    }

    // MARK: 색

    @Test func coverSwatchDarkInkOnLightWarmColor() {
        // 밝은 웜 색 → 정규화해도 고휘도 → 어두운 잉크(프로토타입 톤).
        #expect(PassagePalette.coverSwatch(hex: 0xE0A040).ink == Color(hex: 0x26241F))
    }

    @Test func coverSwatchWhiteInkOnDeepBlue() {
        // 딥 블루 → 정규화해도 저휘도 → 흰 텍스트 자동.
        #expect(PassagePalette.coverSwatch(hex: 0x14205A).ink == Color(hex: 0xFFFFFF))
    }

    // MARK: 색 변환 유틸(PassageColorMath)

    @Test func relativeLuminanceOrdersColors() {
        #expect(PassageColorMath.relativeLuminance(ofHex: 0xFFFFFF) > 0.9)
        #expect(PassageColorMath.relativeLuminance(ofHex: 0x000000) < 0.01)
        #expect(
            PassageColorMath.relativeLuminance(ofHex: 0xEC9C2A)
                > PassageColorMath.relativeLuminance(ofHex: 0x14205A)
        )
    }

    @Test func hsbHexRoundTripWithinRounding() {
        func comp(_ v: UInt32, _ shift: UInt32) -> Int { Int((v >> shift) & 0xFF) }
        for hex in [0xEC9C2A, 0x68839E, 0xA36477, 0x102030, 0xFFFFFF] as [UInt32] {
            let back = PassageColorMath.hex(fromHSB: PassageColorMath.hsb(fromHex: hex))
            #expect(abs(comp(back, 16) - comp(hex, 16)) <= 2)
            #expect(abs(comp(back, 8) - comp(hex, 8)) <= 2)
            #expect(abs(comp(back, 0) - comp(hex, 0)) <= 2)
        }
    }
}
