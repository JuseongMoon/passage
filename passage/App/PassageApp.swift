//
//  PassageApp.swift
//  passage
//
//  앱 진입점. ModelContainer(CloudKit)·서비스 의존성·세션 컨트롤러를 구성해 루트에 주입한다.
//

import SwiftUI
import SwiftData

@main
struct PassageApp: App {
    @State private var dependencies: AppDependencies
    @State private var sessionController: ReadingSessionController
    @State private var pageCountFiller: PageCountFiller
    @State private var coverColorFiller: CoverColorFiller
    private let modelContainer: ModelContainer

    init() {
        let container = PassageModelContainer.makeShared()
        modelContainer = container
        let dependencies = AppDependencies()
        _dependencies = State(initialValue: dependencies)
        _sessionController = State(initialValue: ReadingSessionController(modelContext: container.mainContext))
        _pageCountFiller = State(initialValue: PageCountFiller(
            modelContext: container.mainContext, service: dependencies.pageCount
        ))
        _coverColorFiller = State(initialValue: CoverColorFiller(modelContext: container.mainContext))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(dependencies)
                .environment(sessionController)
                .environment(pageCountFiller)
                .environment(coverColorFiller)
        }
        .modelContainer(modelContainer)
    }
}
