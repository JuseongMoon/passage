//
//  AuthStore.swift
//  passage
//
//  Sign in with Apple 상태 보관·영속화. (DECISIONS #11)
//  자격증명의 이름/이메일은 "최초 로그인"에만 제공되므로 이후엔 기존 값을 보존한다.
//  데이터 정체성은 iCloud(CloudKit)에 묶이며, 로그인은 프로필/계정 표시용.
//

import Foundation
import Observation
import AuthenticationServices

struct UserProfile: Sendable, Identifiable, Codable, Hashable {
    let id: String
    var displayName: String?
    var email: String?
}

@MainActor
@Observable
final class AuthStore {
    private(set) var currentUser: UserProfile?

    private let defaults: UserDefaults
    private let storageKey = "passage.auth.currentUser"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        restore()
    }

    /// SignInWithAppleButton 완료 콜백에서 호출.
    func completeSignIn(_ credential: ASAuthorizationAppleIDCredential) {
        let name = credential.fullName.flatMap { components -> String? in
            let formatted = PersonNameComponentsFormatter().string(from: components)
            return formatted.isEmpty ? nil : formatted
        }
        apply(userID: credential.user, displayName: name, email: credential.email)
    }

    /// 추출한 값을 반영·저장. 이름/이메일이 없으면 기존 값을 유지. (테스트 가능하도록 분리)
    func apply(userID: String, displayName: String?, email: String?) {
        let profile = UserProfile(
            id: userID,
            displayName: displayName ?? currentUser?.displayName,
            email: email ?? currentUser?.email
        )
        currentUser = profile
        persist(profile)
    }

    func signOut() {
        currentUser = nil
        defaults.removeObject(forKey: storageKey)
    }

    /// Apple ID 자격증명이 여전히 유효한지 확인 — 취소/삭제 시 로그아웃. (앱/설정 진입 시 호출)
    func refreshCredentialState() {
        guard let userID = currentUser?.id else { return }
        ASAuthorizationAppleIDProvider().getCredentialState(forUserID: userID) { [weak self] state, _ in
            guard state == .revoked || state == .notFound else { return }
            Task { @MainActor in self?.signOut() }
        }
    }

    private func persist(_ profile: UserProfile) {
        if let data = try? JSONEncoder().encode(profile) {
            defaults.set(data, forKey: storageKey)
        }
    }

    private func restore() {
        guard let data = defaults.data(forKey: storageKey),
              let profile = try? JSONDecoder().decode(UserProfile.self, from: data) else { return }
        currentUser = profile
    }
}
