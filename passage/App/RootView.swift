//
//  RootView.swift
//  passage
//
//  루트 탭 셸(서재 · 독서여정 · 설정) + 전역 활성 세션 표시.
//  독서여정은 지도 중심 화면(JournalView). 회고 진입점은 제거됨(ReflectionView 코드는 존치).
//  독서 중이면 어느 화면에서든 ActiveSessionView를 덮어 띄운다. (ARCHITECTURE §9)
//

import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(ReadingSessionController.self) private var sessionController
    @AppStorage(AppStorageKey.appearanceMode) private var appearanceMode = AppearanceMode.system

    var body: some View {
        TabView {
            Tab("서재", systemImage: "books.vertical") {
                LibraryView()
            }
            Tab("독서여정", systemImage: "ticket") {
                JournalView()
            }
            Tab("설정", systemImage: "gearshape") {
                SettingsView()
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { sessionController.isFlowActive },
            set: { _ in }
        )) {
            if sessionController.phase != nil {
                ReadingSessionView()
            } else if let session = sessionController.sessionAwaitingPlace {
                WhereDidYouReadView(session: session)
            }
        }
        .preferredColorScheme(appearanceMode.colorScheme)   // 설정의 화면 모드(기본=시스템)
    }
}

#Preview {
    RootView().withPreviewEnvironment()
}
