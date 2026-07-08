//
//  NaverMapView.swift
//  passage
//
//  네이버 지도(NMFNaverMapView)를 SwiftUI로 감싼 UIViewRepresentable. (허용된 UIKit 브리지)
//  탭한 지점에 마커를 놓고 좌표를 바인딩으로 돌려준다. SDK 인증은 Info.plist NMFNcpKeyId로 자동.
//

import SwiftUI
import NMapsMap

/// 지도 좌표(Equatable/Sendable) — CLLocationCoordinate2D는 Equatable이 아니라 onChange에 못 쓴다.
struct MapPoint: Equatable, Hashable, Sendable {
    var latitude: Double
    var longitude: Double
}

struct NaverMapView: UIViewRepresentable {
    @Binding var selectedPoint: MapPoint?

    func makeUIView(context: Context) -> NMFNaverMapView {
        let view = NMFNaverMapView()
        view.showLocationButton = false
        view.mapView.touchDelegate = context.coordinator
        return view
    }

    func updateUIView(_ uiView: NMFNaverMapView, context: Context) {
        context.coordinator.render(point: selectedPoint, on: uiView.mapView)
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, NMFMapViewTouchDelegate {
        private let parent: NaverMapView
        private let marker = NMFMarker()
        private var lastRendered: MapPoint?

        init(_ parent: NaverMapView) {
            self.parent = parent
        }

        // SDK 콜백 스레드를 보장할 수 없다 → assumeIsolated(비-메인이면 dispatch_assert_queue
        // 크래시) 대신 MainActor로 홉해서 바인딩을 갱신한다. (프로젝트 관용구: Task { @MainActor in })
        nonisolated func mapView(_ mapView: NMFMapView, didTapMap latlng: NMGLatLng, point: CGPoint) {
            let lat = latlng.lat, lng = latlng.lng   // Sendable(Double)만 경계 너머로
            Task { @MainActor in
                parent.selectedPoint = MapPoint(latitude: lat, longitude: lng)
            }
        }

        func render(point: MapPoint?, on mapView: NMFMapView) {
            guard point != lastRendered else { return }
            lastRendered = point
            if let point {
                let latlng = NMGLatLng(lat: point.latitude, lng: point.longitude)
                marker.position = latlng
                marker.mapView = mapView
                mapView.moveCamera(NMFCameraUpdate(scrollTo: latlng))
            } else {
                marker.mapView = nil
            }
        }
    }
}
