//
//  Place.swift
//  passage
//
//  독서한 장소. 이름은 필수, 위치·주소는 선택.
//  사진은 장소가 아니라 세션이 갖는다(→ SessionPhoto, DECISIONS #27).
//  기존 장소를 재사용하거나 새로 만든다.
//  저장 속성·관계는 스키마 스냅샷에 있고 여기엔 동작만 둔다. (→ Schema/PassageSchema.swift)
//

import Foundation
import SwiftData

// nonisolated: 모델 동작도 SwiftData 내부 스레드에서 불릴 수 있다(→ Schema/PassageSchemaV1.swift 주석).
nonisolated extension Place {
    convenience init(name: String = "", latitude: Double? = nil, longitude: Double? = nil, address: String? = nil) {
        self.init()
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
    }

    /// 좌표가 있는 경우에만 위치를 노출.
    var hasCoordinate: Bool { latitude != nil && longitude != nil }
}
