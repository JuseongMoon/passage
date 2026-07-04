//
//  SettingsView.swift
//  passage
//
//  설정 — 계정(Sign in with Apple 더미) · 앱 정보.
//  로그인은 더미 버튼만 두고, 실제 연동은 후속(Phase 2). (DECISIONS #11)
//

import SwiftUI
import AuthenticationServices

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    SignInWithAppleButton(.signIn) { _ in
                        // 실제 요청 구성은 Phase 2
                    } onCompletion: { _ in
                        // 자격 증명 처리는 Phase 2
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 50)
                    .frame(maxWidth: 375)   // ASAuthorizationAppleIDButton 최대 폭(넓은 화면 제약 충돌 방지)
                    .clipShape(.rect(cornerRadius: Theme.Radius.md, style: .continuous))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .disabled(true)   // 더미: 아직 비활성
                    .accessibilityLabel("Apple로 로그인 (준비 중)")
                } header: {
                    Text("계정")
                } footer: {
                    Text("로그인은 곧 지원될 예정이에요. 지금도 기록은 iCloud로 안전하게 동기화됩니다.")
                }

                Section("정보") {
                    LabeledContent("버전", value: Bundle.appVersion)
                }
            }
            .navigationTitle("설정")
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
}
