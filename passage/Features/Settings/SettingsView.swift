//
//  SettingsView.swift
//  passage
//
//  설정 — 계정(Sign in with Apple 더미) · 앱 정보.
//  로그인은 더미 버튼만 두고, 실제 연동은 나머지 완성 후 진행. (DECISIONS #11)
//

import SwiftUI
import AuthenticationServices

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    SignInWithAppleButton(.signIn) { _ in
                        // Phase 2에서 실제 요청 구성
                    } onCompletion: { _ in
                        // Phase 2에서 자격 증명 처리
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 48)
                    .clipShape(.rect(cornerRadius: Theme.Radius.md, style: .continuous))
                    .disabled(true)   // 더미: 아직 비활성
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                } header: {
                    Text("계정")
                } footer: {
                    Text("로그인은 준비 중이에요. 데이터는 iCloud로 안전하게 동기화됩니다.")
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
        let version = main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        return version
    }
}

#Preview {
    SettingsView()
}
