//
//  AppDependencies.swift
//  passage
//
//  앱 전역 서비스 컨테이너. 루트에서 1회 Environment 주입. (→ ARCHITECTURE §10)
//  Preview·테스트에서는 다른 구현을 주입해 교체한다.
//

import Foundation
import Observation

@MainActor
@Observable
final class AppDependencies {
    let imageStore: any ImageStore
    let geocoding: any GeocodingService
    let bookSearch: any BookSearchService
    let placeSearch: any PlaceSearchService
    let pageCount: any PageCountService
    let auth: AuthStore
    let location: LocationService

    init(
        imageStore: any ImageStore = LocalImageStore(),
        geocoding: any GeocodingService = NaverMapService(),
        bookSearch: any BookSearchService = NaverBookSearchService(),
        placeSearch: any PlaceSearchService = NaverPlaceSearchService(),
        pageCount: any PageCountService = CompositePageCountService(providers: [
            AladinPageCountService(),
            GoogleBooksPageCountService(service: GoogleBooksSearchService())
        ]),
        auth: AuthStore = AuthStore(),
        location: LocationService = LocationService()
    ) {
        self.imageStore = imageStore
        self.geocoding = geocoding
        self.bookSearch = bookSearch
        self.placeSearch = placeSearch
        self.pageCount = pageCount
        self.auth = auth
        self.location = location
    }
}
