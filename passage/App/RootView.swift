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
import CoreLocation

struct RootView: View {
    @Environment(ReadingSessionController.self) private var sessionController
    @Environment(AppDependencies.self) private var dependencies
    @AppStorage(AppStorageKey.appearanceMode) private var appearanceMode = AppearanceMode.system
    @State private var router = AppRouter()

    var body: some View {
        TabView(selection: $router.selectedTab) {
            Tab("서재", systemImage: "books.vertical", value: RootTab.library) {
                LibraryView()
            }
            Tab("독서여정", systemImage: "ticket", value: RootTab.journal) {
                JournalView()
            }
            Tab("설정", systemImage: "gearshape", value: RootTab.settings) {
                SettingsView()
            }
        }
        .environment(router)
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
        .task {
            // 앱 시작 시 위치 권한을 한 번 요청(장소 자동채움 보조). 미결정일 때만 프롬프트.
            if dependencies.location.authorizationStatus == .notDetermined {
                dependencies.location.requestWhenInUseAuthorization()
            }
        }
    }
}

#Preview {
    RootView().withPreviewEnvironment()
}
