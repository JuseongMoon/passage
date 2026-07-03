//
//  LocationService.swift
//  passage
//
//  위치 제공 추상화. GPS는 선택 기능(장소 기록 보조). (→ ARCHITECTURE §7)
//  CoreLocation 델리게이트 콜백은 임의 스레드에서 오므로 nonisolated로 받아 MainActor로 넘긴다.
//

import CoreLocation
import Observation

@MainActor
protocol LocationProviding: AnyObject {
    var authorizationStatus: CLAuthorizationStatus { get }
    func requestWhenInUseAuthorization()
    func currentLocation() async throws -> CLLocationCoordinate2D
}

@MainActor
@Observable
final class LocationService: NSObject, LocationProviding, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    private var continuation: CheckedContinuation<CLLocationCoordinate2D, Error>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorizationStatus = manager.authorizationStatus
    }

    func requestWhenInUseAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    /// 1회성 현재 위치. 진행 중 요청이 있으면 취소하고 갱신한다.
    func currentLocation() async throws -> CLLocationCoordinate2D {
        continuation?.resume(throwing: CancellationError())
        continuation = nil
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            manager.requestLocation()
        }
    }

    // MARK: - CLLocationManagerDelegate (nonisolated → MainActor 홉)

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let coordinate = locations.last?.coordinate
        Task { @MainActor in
            guard let coordinate else { return }
            continuation?.resume(returning: coordinate)
            continuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            continuation?.resume(throwing: error)
            continuation = nil
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            authorizationStatus = status
        }
    }
}
