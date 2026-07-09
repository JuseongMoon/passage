//
//  JourneyMapView.swift
//  passage
//
//  독서여정 지도(NMFNaverMapView 브리지). 책 표지를 읽은 장소에 마커로 꽂고,
//  한 책을 선택하면 그 책의 장소들을 점선 경로로 연결하고 이름·체류시간 캡션을 단다.
//  장소 피커용 NaverMapView(단일 지점)와 별개로, 여러 마커·오버레이를 관리하는 전용 브리지.
//
//  MainActor 격리: SDK 콜백(마커 탭)엔 Sendable 값(UUID)만 넘기고 Task{@MainActor}로 홉,
//  SDK에 넘기는 색은 traitCollection으로 미리 해석한 정적 UIColor(off-main dynamicProvider 회피).
//

import SwiftUI
import NMapsMap

struct JourneyMapView: UIViewRepresentable {
    let journeys: [BookJourney]          // 필터 적용된 목록
    @Binding var selectedBookID: UUID?
    let fallback: MapPoint?              // 좌표 없는 장소 대체(현재 위치)

    func makeUIView(context: Context) -> NMFNaverMapView {
        let view = NMFNaverMapView()
        view.showLocationButton = false
        view.showZoomControls = false
        view.showCompass = false
        view.showScaleBar = false
        return view
    }

    func updateUIView(_ uiView: NMFNaverMapView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.render(on: uiView.mapView)
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject {
        var parent: JourneyMapView
        private var markers: [NMFMarker] = []
        private var polyline: NMFPolylineOverlay?
        private let renderer = BookCoverMarkerRenderer()
        private var lastKey = ""
        private var currentCoords: [NMGLatLng] = []

        init(_ parent: JourneyMapView) { self.parent = parent }

        /// 선택/목록이 바뀔 때만 다시 그린다(표지 로드 완료는 마커 iconImage만 갱신 → 전체 재렌더 아님).
        func render(on mapView: NMFMapView) {
            let journeys = parent.journeys
            let selected = parent.selectedBookID
            // 좌표 없는 장소는 fallback(현재 위치)로 그려지므로 fallback이 도착하면 다시 그린다.
            let fallbackKey = parent.fallback.map { "\($0.latitude),\($0.longitude)" } ?? "none"
            let key = (selected?.uuidString ?? "all") + "|" + fallbackKey + "|"
                + journeys.map(\.id.uuidString).joined(separator: ",")
            guard key != lastKey else { return }
            lastKey = key

            clear()
            if let selected, let journey = journeys.first(where: { $0.id == selected }) {
                renderFocus(journey, on: mapView)
            } else {
                renderOverview(journeys, on: mapView)
            }
            fitCamera(currentCoords, on: mapView)
        }

        private func clear() {
            markers.forEach { $0.mapView = nil }
            markers.removeAll()
            polyline?.mapView = nil
            polyline = nil
        }

        // MARK: 개요 — 책마다 대표 위치에 표지 마커 1개

        private func renderOverview(_ journeys: [BookJourney], on mapView: NMFMapView) {
            var coords: [NMGLatLng] = []
            for journey in journeys {
                guard let point = representativePoint(journey) else { continue }
                let latlng = NMGLatLng(lat: point.latitude, lng: point.longitude)
                coords.append(latlng)

                let marker = makeMarker(at: latlng, journey: journey, caption: nil, on: mapView)
                let id = journey.id
                let parent = self.parent
                marker.touchHandler = { _ in
                    Task { @MainActor in parent.selectedBookID = id }
                    return true
                }
                marker.mapView = mapView
                markers.append(marker)
            }
            currentCoords = coords
        }

        // MARK: 포커스 — 선택 책의 장소들을 점선으로 연결 + 이름·체류시간 캡션

        private func renderFocus(_ journey: BookJourney, on mapView: NMFMapView) {
            var coords: [NMGLatLng] = []
            for stop in journey.stops {
                guard let point = point(for: stop) else { continue }
                let latlng = NMGLatLng(lat: point.latitude, lng: point.longitude)
                coords.append(latlng)
                let marker = makeMarker(
                    at: latlng, journey: journey,
                    caption: "\(stop.name) · \(stop.durationText)", on: mapView
                )
                marker.mapView = mapView
                markers.append(marker)
            }
            if coords.count >= 2, let line = NMFPolylineOverlay(coords) {
                line.color = resolved(PassagePalette.warmAccent, on: mapView)
                line.width = 3
                line.pattern = [6, 6]                 // 점선(온·오프 길이)
                line.mapView = mapView
                polyline = line
            }
            currentCoords = coords
        }

        // MARK: 마커 생성 (폴백 즉시 표시 → 표지 로드 완료 시 교체)

        private func makeMarker(at latlng: NMGLatLng, journey: BookJourney, caption: String?, on mapView: NMFMapView) -> NMFMarker {
            let marker = NMFMarker()
            marker.position = latlng
            marker.width = BookCoverMarkerRenderer.markerSize.width
            marker.height = BookCoverMarkerRenderer.markerSize.height
            marker.anchor = CGPoint(x: 0.5, y: 0.5)
            marker.iconImage = NMFOverlayImage(image: renderer.placeholder(for: journey.swatch))
            if let caption {
                marker.captionText = caption
                marker.captionTextSize = 11
                marker.captionColor = resolved(PassagePalette.ink, on: mapView)
                marker.captionHaloColor = resolved(PassagePalette.appBg, on: mapView)
            }

            let renderer = self.renderer
            let id = journey.id, url = journey.coverURL, swatch = journey.swatch
            Task { @MainActor [weak marker] in
                let image = await renderer.load(id: id, coverURL: url, swatch: swatch)
                if let marker, marker.mapView != nil {
                    marker.iconImage = NMFOverlayImage(image: image)
                }
            }
            return marker
        }

        // MARK: 좌표 해석(없으면 현재 위치 fallback)

        private func representativePoint(_ journey: BookJourney) -> MapPoint? {
            if let stop = journey.stops.first(where: { $0.hasCoordinate }),
               let lat = stop.latitude, let lng = stop.longitude {
                return MapPoint(latitude: lat, longitude: lng)
            }
            return parent.fallback
        }

        private func point(for stop: JourneyStop) -> MapPoint? {
            if let lat = stop.latitude, let lng = stop.longitude {
                return MapPoint(latitude: lat, longitude: lng)
            }
            return parent.fallback
        }

        /// 마커가 모두 보이도록 카메라를 맞춘다. fitBounds의 padding 파라미터가 실기에서 무시되는 경우가 있어
        /// bounds 자체를 여백만큼 넓혀 극단 마커가 가장자리에 걸리지 않게 한다.
        /// 첫 렌더는 뷰 크기가 0일 수 있어(레이아웃 전) 크기가 잡힌 뒤 실행되도록 async로 미룬다.
        private func fitCamera(_ coords: [NMGLatLng], on mapView: NMFMapView) {
            guard !coords.isEmpty else { return }
            let apply = { [weak mapView] in
                guard let mapView, mapView.frame.width > 1, mapView.frame.height > 1 else { return }
                if coords.count == 1 {
                    mapView.moveCamera(NMFCameraUpdate(scrollTo: coords[0], zoomTo: 14))
                } else {
                    let lats = coords.map(\.lat), lngs = coords.map(\.lng)
                    let minLat = lats.min()!, maxLat = lats.max()!
                    let minLng = lngs.min()!, maxLng = lngs.max()!
                    let latPad = max((maxLat - minLat) * 0.35, 0.004)
                    let lngPad = max((maxLng - minLng) * 0.35, 0.004)
                    let bounds = NMGLatLngBounds(
                        southWest: NMGLatLng(lat: minLat - latPad, lng: minLng - lngPad),
                        northEast: NMGLatLng(lat: maxLat + latPad, lng: maxLng + lngPad)
                    )
                    mapView.moveCamera(NMFCameraUpdate(fit: bounds))
                }
            }
            if mapView.frame.width > 1, mapView.frame.height > 1 {
                apply()
            } else {
                DispatchQueue.main.async(execute: apply)
            }
        }

        /// SwiftUI 동적 Color를 현재 trait로 미리 해석한 정적 UIColor(SDK가 off-main에서 재해석해도 안전).
        private func resolved(_ color: Color, on mapView: NMFMapView) -> UIColor {
            UIColor(color).resolvedColor(with: mapView.traitCollection)
        }
    }
}
