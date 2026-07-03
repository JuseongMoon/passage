//
//  ReadingFlowUITests.swift
//  passageUITests
//
//  핵심 플로우 end-to-end: 책 추가 → 읽기 시작 → 종료 → "어디서 읽으셨나요?" → 새 장소(지도).
//

import XCTest

final class ReadingFlowUITests: XCTestCase {

    @MainActor
    func testReadToPlaceFlow() throws {
        let app = XCUIApplication()
        app.launch()

        // 1. 책 추가
        let addButton = app.buttons["책 추가"].firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: 8), "책 추가 버튼")
        addButton.tap()

        // 2. 제목 입력 (ASCII로 IME 이슈 회피)
        let titleField = app.textFields["제목"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5), "제목 필드")
        titleField.tap()
        titleField.typeText("Book1")

        // 3. 저장
        app.buttons["저장"].tap()

        // 4. 책 행 탭 → 상세
        let bookRow = app.staticTexts["Book1"]
        XCTAssertTrue(bookRow.waitForExistence(timeout: 5), "책 행")
        bookRow.tap()

        // 5. 읽기 시작
        let startButton = app.buttons["읽기 시작"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5), "읽기 시작")
        startButton.tap()

        // 6. 독서 종료 (활성 세션 화면)
        let stopButton = app.buttons["독서 종료"]
        XCTAssertTrue(stopButton.waitForExistence(timeout: 5), "독서 종료")
        stopButton.tap()

        // 7. "어디서 읽으셨나요?" → 새 장소
        let newPlaceButton = app.buttons["새 장소"]
        XCTAssertTrue(newPlaceButton.waitForExistence(timeout: 5), "새 장소 (종료 후 장소 프롬프트)")
        newPlaceButton.tap()

        // 8. 새 장소 화면(지도 포함) 도달 확인 + 스크린샷
        let nameField = app.textFields["이름"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "새 장소 이름 필드(=지도 화면 도달)")

        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "NewPlaceMap"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
