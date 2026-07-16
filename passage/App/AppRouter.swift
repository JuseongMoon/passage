//
//  AppRouter.swift
//  passage
//
//  탭 전환 + Feature를 가로지르는 딥 내비게이션 좌표.
//  서재 "여정보기"가 독서여정 탭의 "책 포커스"로 건너가는 것처럼, 한 화면에서 다른
//  탭의 특정 상태로 이동하는 흐름을 여기 한 곳에서 조율한다(Feature 간 직접 의존 회피).
//

import SwiftUI

/// 루트 탭 식별자.
enum RootTab: Hashable, Sendable {
    case library, journal, settings
}

/// 앱 전역 내비게이션 상태 — 선택된 탭 + 독서여정 포커스 요청.
@Observable @MainActor
final class AppRouter {
    /// 현재 선택된 탭.
    var selectedTab: RootTab = .library

    /// 독서여정 탭이 포커스할 책 id. `JournalView`가 소비하면 스스로 nil로 되돌린다.
    /// (탭 전환과 포커스를 한 번의 의도로 묶기 위한 1회성 요청 값)
    var journeyFocusRequest: UUID?

    /// 특정 책의 여정을 독서여정 탭에서 열도록 요청(탭 전환 + 포커스).
    func openJourney(bookID: UUID) {
        journeyFocusRequest = bookID
        selectedTab = .journal
    }
}
