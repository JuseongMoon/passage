//
//  WhereDidYouReadView.swift
//  passage
//
//  독서 종료 직후 "어디서 읽으셨나요?" 질문. 기존 장소 선택 / 새 장소 / 건너뛰기.
//  장소는 선택 사항이며, 건너뛰어도 세션(기억)은 그대로 남는다.
//

import SwiftUI
import SwiftData

struct WhereDidYouReadView: View {
    @Environment(ReadingSessionController.self) private var controller
    @Query(sort: \Place.dateCreated, order: .reverse) private var places: [Place]
    @State private var showingNewPlace = false
    let session: ReadingSession

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        showingNewPlace = true
                    } label: {
                        Label("새 장소", systemImage: "plus.circle.fill")
                            .font(.headline)
                    }
                }

                if !places.isEmpty {
                    Section("최근 장소") {
                        ForEach(places) { place in
                            Button {
                                controller.assignPlace(place, to: session)
                            } label: {
                                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                                    Text(place.name).foregroundStyle(.primary)
                                    if let address = place.address, !address.isEmpty {
                                        Text(address)
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("어디서 읽으셨나요?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("건너뛰기") { controller.skipPlacePrompt() }
                }
            }
            .sheet(isPresented: $showingNewPlace) {
                NewPlaceView(session: session)
            }
        }
    }
}
