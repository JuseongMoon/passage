//
//  SettingsView.swift
//  passage
//
//  설정 — 계정(Sign in with Apple) · 앱 정보.
//  서재와 같은 웜 팔레트 톤(appBg·커스텀 헤더·cardBody 카드 섹션). (→ DECISIONS #18)
//

import SwiftUI
import AuthenticationServices

struct SettingsView: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(AppStorageKey.appearanceMode) private var appearanceMode = AppearanceMode.system

    var body: some View {
        NavigationStack {
            ZStack {
                PassagePalette.appBg.ignoresSafeArea()

                VStack(spacing: 0) {
                    PassageScreenHeader(title: "설정")
                    settingsList
                }
            }
            .toolbar(.hidden, for: .navigationBar)   // 커스텀 헤더 사용
            .task { dependencies.auth.refreshCredentialState() }
        }
    }

    // MARK: 리스트

    private var settingsList: some View {
        List {
            Section {
                accountContent
            } header: {
                sectionHeader("계정")
            } footer: {
                Text(dependencies.auth.currentUser == nil
                     ? "Apple로 로그인하면 기기 간 프로필이 유지돼요. 기록은 iCloud로 안전하게 동기화됩니다."
                     : "기록은 iCloud로 안전하게 동기화됩니다.")
                    .font(.footnote)
                    .foregroundStyle(PassagePalette.inkMuted)
            }
            .listRowBackground(PassagePalette.cardBody)

            Section {
                Picker("화면 모드", selection: $appearanceMode) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                sectionHeader("화면")
            }
            .listRowBackground(PassagePalette.cardBody)

            Section {
                LabeledContent("버전", value: Bundle.appVersion)
            } header: {
                sectionHeader("정보")
            }
            .listRowBackground(PassagePalette.cardBody)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)   // 시스템 리스트 배경 숨김 → appBg 노출
        .foregroundStyle(PassagePalette.ink)
        .tint(PassagePalette.warmAccent)
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(PassagePalette.inkMuted)
            .textCase(nil)
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
            .foregroundStyle(PassagePalette.danger)
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
            .listRowBackground(Color.clear)   // 버튼 자체가 표면 → 카드 배경 제거
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
