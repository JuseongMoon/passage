//
//  PlacePhoto.swift
//  passage
//
//  장소 사진. 바이너리를 SwiftData externalStorage로 저장 → SwiftData+CloudKit이
//  CKAsset으로 기기 간 자동 동기화. (기존 로컬 파일 ImageStore 방식 대체)
//

import Foundation
import SwiftData

// nonisolated: SwiftData 내부 스레드 접근 허용(→ Book.swift 주석 참고).
@Model
nonisolated final class PlacePhoto {
    var id: UUID = UUID()
    @Attribute(.externalStorage) var data: Data?
    var dateAdded: Date = Date()

    var place: Place?

    init(data: Data? = nil, place: Place? = nil) {
        self.data = data
        self.place = place
    }
}
