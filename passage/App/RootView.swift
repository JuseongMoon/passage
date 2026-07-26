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
        // 시스템 탭바는 숨기고(재질/블러가 목업의 차분한 톤을 깬다) 커스텀 바를
        // safeAreaInset으로 얹는다. TabView는 그대로 두어 탭별 lazy 로딩·상태 보존은 유지한다.
        TabView(selection: $router.selectedTab) {
            Tab(value: RootTab.library) { LibraryView() }
            Tab(value: RootTab.journal) { JournalView() }
            Tab(value: RootTab.settings) { SettingsView() }
        }
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            PassageTabBar(selection: $router.selectedTab)
        }
        .environment(router)
        .fullScreenCover(isPresented: Binding(
            get: { sessionController.isFlowActive },
            set: { _ in }
        )) {
            ReadingSessionView()
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

/// 커스텀 하단 탭바 — 아이콘 + 라벨, 선택은 잉크색/두께로만 구분한다(배지·강조색 없음).
private struct PassageTabBar: View {
    @Binding var selection: RootTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(RootTab.allCases) { tab in
                item(tab)
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 4)
        .background {
            PassagePalette.appBg
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(PassagePalette.hairline)
                        .frame(height: 0.5)
                }
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private func item(_ tab: RootTab) -> some View {
        let isSelected = selection == tab
        return Button {
            if selection != tab { selection = tab }
        } label: {
            VStack(spacing: 5) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 21, weight: isSelected ? .medium : .light))
                Text(tab.title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
            }
            .foregroundStyle(isSelected ? PassagePalette.ink : PassagePalette.inkFaint)
            .frame(maxWidth: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview {
    RootView().withPreviewEnvironment()
}
