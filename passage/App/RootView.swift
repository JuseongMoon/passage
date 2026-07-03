//
//  RootView.swift
//  passage
//
//  루트 탭 셸. 서재 · 저널 · 설정.
//  "읽기 시작"은 탭이 아니라 서재의 책에서 시작하는 액션이다. (ARCHITECTURE §9)
//

import SwiftUI
import SwiftData

struct RootView: View {
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
    }
}

#Preview {
    RootView()
        .modelContainer(PassageModelContainer.makePreview())
        .environment(AppDependencies())
}
