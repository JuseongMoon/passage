//
//  Place.swift
//  passage
//
//  독서한 장소. 이름은 필수, 위치·주소는 선택.
//  사진은 장소가 아니라 세션이 갖는다(→ SessionPhoto, DECISIONS #27).
//  기존 장소를 재사용하거나 새로 만든다.
//

import Foundation
import SwiftData

// nonisolated: SwiftData 내부 스레드 접근 허용(→ Book.swift 주석 참고).
@Model
nonisolated final class Place {
    var id: UUID = UUID()
    var name: String = ""
    var latitude: Double?
    var longitude: Double?
    var address: String?
    var dateCreated: Date = Date()

    // 장소 삭제 시 세션의 place만 nullify(기억은 남고 장소만 사라짐).
    @Relationship(deleteRule: .nullify, inverse: \ReadingSession.place)
    var sessions: [ReadingSession]? = []

    init(name: String = "", latitude: Double? = nil, longitude: Double? = nil, address: String? = nil) {
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
    }

    /// 좌표가 있는 경우에만 위치를 노출.
    var hasCoordinate: Bool { latitude != nil && longitude != nil }
}
