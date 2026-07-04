//
//  AuthStoreTests.swift
//  passageTests
//
//  Apple 로그인 상태 영속·복원·재로그인 값 보존 검증(자격증명 없이 apply로).
//

import Testing
import Foundation
@testable import passage

@MainActor
struct AuthStoreTests {

    /// 테스트마다 격리된 빈 UserDefaults suite.
    private func freshDefaults() -> UserDefaults {
        UserDefaults(suiteName: "passage.tests.auth.\(UUID().uuidString)")!
    }

    @Test func applyPersistsAndRestores() {
        let defaults = freshDefaults()
        let store = AuthStore(defaults: defaults)
        #expect(store.currentUser == nil)

        store.apply(userID: "u1", displayName: "독서가", email: "a@b.com")
        #expect(store.currentUser?.id == "u1")
        #expect(store.currentUser?.displayName == "독서가")

        let restored = AuthStore(defaults: defaults)   // 재생성 시 복원
        #expect(restored.currentUser?.id == "u1")
        #expect(restored.currentUser?.email == "a@b.com")
    }

    @Test func reSignInPreservesNameAndEmail() {
        let defaults = freshDefaults()
        let store = AuthStore(defaults: defaults)
        store.apply(userID: "u1", displayName: "독서가", email: "a@b.com")

        // Apple 재로그인은 이름/이메일 없이 오는 경우가 많음 → 기존 값 보존
        store.apply(userID: "u1", displayName: nil, email: nil)
        #expect(store.currentUser?.displayName == "독서가")
        #expect(store.currentUser?.email == "a@b.com")
    }

    @Test func signOutClearsAndErasesPersisted() {
        let defaults = freshDefaults()
        let store = AuthStore(defaults: defaults)
        store.apply(userID: "u1", displayName: "독서가", email: nil)

        store.signOut()
        #expect(store.currentUser == nil)
        #expect(AuthStore(defaults: defaults).currentUser == nil)
    }
}
