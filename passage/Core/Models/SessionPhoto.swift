//
//  SessionPhoto.swift
//  passage
//
//  한 세션에서 남긴 사진. 바이너리는 SwiftData externalStorage로 저장 →
//  SwiftData+CloudKit이 CKAsset으로 기기 간 자동 동기화.
//
//  소유자는 장소가 아니라 **세션**이다(구 PlacePhoto 대체). 장소에 붙이면 같은 곳에서 읽은
//  모든 세션이 사진을 공유해 "그날 그 자리"가 아니라 "그 장소"의 사진이 된다. (→ DECISIONS #27)
//

import Foundation
import SwiftData

// nonisolated: SwiftData 내부 스레드 접근 허용(→ Book.swift 주석 참고).
@Model
nonisolated final class SessionPhoto {
    // CloudKit 규칙: 모든 저장 속성은 optional 또는 기본값. 관계는 optional + inverse 필수.
    var id: UUID = UUID()
    @Attribute(.externalStorage) var data: Data?
    var dateAdded: Date = Date()

    var session: ReadingSession?

    init(data: Data? = nil, session: ReadingSession? = nil) {
        self.data = data
        self.session = session
    }
}
