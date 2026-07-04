//
//  NewPlaceView.swift
//  passage
//
//  새 장소 생성. 이름(필수) · 지도 지점/현재 위치(선택) · 주소 자동(reverse-geocode) · 사진(선택).
//  사진은 LocalImageStore(로컬 파일)에 저장하고 참조만 Place에 담는다.
//

import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct NewPlaceView: View {
    @Environment(ReadingSessionController.self) private var controller
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let session: ReadingSession

    @State private var name = ""
    @State private var address = ""
    @State private var selectedPoint: MapPoint?
    @State private var photoItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var isSaving = false
    @State private var isLocating = false
    @State private var isGeocoding = false

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSaving
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("장소") {
                    TextField("이름", text: $name)
                }

                Section {
                    NaverMapView(selectedPoint: $selectedPoint)
                        .frame(height: 220)
                        .listRowInsets(EdgeInsets())
                        .accessibilityLabel("지도. 눌러서 읽은 위치를 선택하세요.")
                    Button {
                        useCurrentLocation()
                    } label: {
                        HStack {
                            Label("현재 위치 사용", systemImage: "location.fill")
                            if isLocating {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isLocating)
                    if isGeocoding {
                        HStack(spacing: Theme.Spacing.xs) {
                            ProgressView()
                            Text("주소를 찾는 중…")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    } else if !address.isEmpty {
                        Text(address)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("위치 (선택)")
                } footer: {
                    Text("지도를 눌러 지점을 고르거나 현재 위치를 사용하세요.")
                }

                Section("사진 (선택)") {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label("사진 추가", systemImage: "photo")
                    }
                    if let photoData, let image = UIImage(data: photoData) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 160)
                            .frame(maxWidth: .infinity)
                            .clipped()
                            .listRowInsets(EdgeInsets())
                            .accessibilityLabel("선택한 사진")
                    }
                }
            }
            .navigationTitle("새 장소")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { save() }.disabled(!canSave)
                }
            }
            .onChange(of: selectedPoint) { _, newValue in
                guard let newValue else { return }
                reverseGeocode(newValue)
            }
            .onChange(of: photoItem) { _, newItem in
                Task { photoData = try? await newItem?.loadTransferable(type: Data.self) }
            }
        }
    }

    private func useCurrentLocation() {
        isLocating = true
        Task {
            dependencies.location.requestWhenInUseAuthorization()
            let coordinate = try? await dependencies.location.currentLocation()
            isLocating = false
            if let coordinate {
                selectedPoint = MapPoint(latitude: coordinate.latitude, longitude: coordinate.longitude)
            }
        }
    }

    private func reverseGeocode(_ point: MapPoint) {
        isGeocoding = true
        Task {
            let resolved = try? await dependencies.geocoding.reverseGeocode(
                latitude: point.latitude, longitude: point.longitude
            )
            isGeocoding = false
            if let resolved { address = resolved }
        }
    }

    private func save() {
        isSaving = true
        let place = Place(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            latitude: selectedPoint?.latitude,
            longitude: selectedPoint?.longitude,
            address: address.isEmpty ? nil : address
        )
        modelContext.insert(place)
        // 사진은 externalStorage 모델로 저장 → CloudKit 자동 동기화.
        if let photoData {
            modelContext.insert(PlacePhoto(data: photoData, place: place))
        }
        controller.assignPlace(place, to: session)
        dismiss()
    }
}
