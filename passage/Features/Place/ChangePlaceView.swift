//
//  ChangePlaceView.swift
//  passage
//
//  독서기록(세션)의 독서 위치를 바꾸거나 새로 지정하는 시트.
//  기존 장소 재사용 또는 새 장소(NewPlaceView) 생성 → 세션에 재할당.
//  시트로 떠서 세션 장소가 바뀌면 스스로 닫힌다(세션 플로우 상태 비의존).
//

import SwiftUI
import SwiftData

struct ChangePlaceView: View {
    @Environment(ReadingSessionController.self) private var controller
    @Environment(\.dismiss) private var dismiss
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
                    Section("장소 선택") {
                        ForEach(places) { place in
                            Button {
                                controller.assignPlace(place, to: session)   // session.place 갱신 + 저장
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                                        Text(place.name).foregroundStyle(.primary)
                                        if let address = place.address, !address.isEmpty {
                                            Text(address)
                                                .font(.footnote)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    if place.id == session.place?.id {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(PassagePalette.warmAccent)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("독서 위치")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
            }
            .sheet(isPresented: $showingNewPlace) {
                NewPlaceView(session: session)
            }
            // 기존/새 장소 어느 쪽으로든 세션 장소가 바뀌면 시트를 닫는다.
            .onChange(of: session.place?.id) { _, _ in
                dismiss()
            }
        }
    }
}
