//
//  SettingsView.swift
//  passage
//
//  설정 — 계정(Sign in with Apple) · 앱 정보.
//

import SwiftUI
import AuthenticationServices

struct SettingsView: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            List {
                Section {
                    accountContent
                } header: {
                    Text("계정")
                } footer: {
                    Text(dependencies.auth.currentUser == nil
                         ? "Apple로 로그인하면 기기 간 프로필이 유지돼요. 기록은 iCloud로 안전하게 동기화됩니다."
                         : "기록은 iCloud로 안전하게 동기화됩니다.")
                }

                Section("정보") {
                    LabeledContent("버전", value: Bundle.appVersion)
                }
            }
            .navigationTitle("설정")
            .task { dependencies.auth.refreshCredentialState() }
        }
    }

    @ViewBuilder private var accountContent: some View {
        if let user = dependencies.auth.currentUser {
            LabeledContent("로그인됨", value: user.displayName ?? "Apple 사용자")
            if let email = user.email, !email.isEmpty {
                LabeledContent("이메일", value: email)
            }
            Button("로그아웃", role: .destructive) {
                dependencies.auth.signOut()
            }
        } else {
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                if case .success(let authorization) = result,
                   let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
                    dependencies.auth.completeSignIn(credential)
                }
            }
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 50)
            .frame(maxWidth: 375)   // ASAuthorizationAppleIDButton 최대 폭(넓은 화면 제약 충돌 방지)
            .clipShape(.rect(cornerRadius: Theme.Radius.md, style: .continuous))
            .frame(maxWidth: .infinity, alignment: .center)
            .accessibilityLabel("Apple로 로그인")
        }
    }
}

private extension Bundle {
    static var appVersion: String {
        main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }
}

#Preview {
    SettingsView()
        .withPreviewEnvironment()
}
