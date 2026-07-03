//
//  AuthService.swift
//  passage
//
//  인증 추상화. MVP는 DummyAuthService(더미 버튼). 실제 Sign in with Apple은 후속. (DECISIONS #11)
//  데이터 정체성은 iCloud(CloudKit)에 묶이므로, 로그인은 향후 계정/프로필용이다.
//

import Foundation

struct UserProfile: Sendable, Identifiable, Codable, Hashable {
    let id: String
    var displayName: String?
    var email: String?
}

protocol AuthService: Sendable {
    var currentUser: UserProfile? { get async }
    func signIn() async throws -> UserProfile
    func signOut() async
}

/// 더미 구현: 실제 인증 없이 임시 사용자만 반환(연결은 Phase 2).
actor DummyAuthService: AuthService {
    private var user: UserProfile?

    var currentUser: UserProfile? { user }

    func signIn() async throws -> UserProfile {
        let profile = UserProfile(id: "dummy-user", displayName: "독서가", email: nil)
        user = profile
        return profile
    }

    func signOut() async {
        user = nil
    }
}
