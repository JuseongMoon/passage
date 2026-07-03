//
//  RootView.swift
//  passage
//
//  루트 탭 셸(서재 · 저널 · 설정) + 전역 활성 세션 표시.
//  독서 중이면 어느 화면에서든 ActiveSessionView를 덮어 띄운다. (ARCHITECTURE §9)
//

import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(ReadingSessionController.self) private var sessionController

    var body: some View {
        TabView {
            Tab("서재", systemImage: "books.vertical") {
                LibraryView()
            }
            Tab("저널", systemImage: "book.closed") {
                JournalView()
            }
            Tab("설정", systemImage: "gearshape") {
                SettingsView()
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { sessionController.isReading },
            set: { _ in }
        )) {
            if let session = sessionController.activeSession {
                ActiveSessionView(session: session)
            }
        }
    }
}

#Preview {
    RootView().withPreviewEnvironment()
}
