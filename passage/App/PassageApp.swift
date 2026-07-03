//
//  PassageApp.swift
//  passage
//
//  앱 진입점. ModelContainer(CloudKit)와 서비스 의존성을 구성해 루트에 주입한다.
//

import SwiftUI
import SwiftData

@main
struct PassageApp: App {
    @State private var dependencies = AppDependencies()
    private let modelContainer = PassageModelContainer.makeShared()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(dependencies)
        }
        .modelContainer(modelContainer)
    }
}
