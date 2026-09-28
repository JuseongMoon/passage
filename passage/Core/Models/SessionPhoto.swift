//
//  SessionPhoto.swift
//  passage
//
//  한 세션에서 남긴 사진. 바이너리는 SwiftData externalStorage로 저장 →
//  SwiftData+CloudKit이 CKAsset으로 기기 간 자동 동기화.
//
//  소유자는 장소가 아니라 **세션**이다(구 PlacePhoto 대체). 장소에 붙이면 같은 곳에서 읽은
//  모든 세션이 사진을 공유해 "그날 그 자리"가 아니라 "그 장소"의 사진이 된다. (→ DECISIONS #27)
//  저장 속성·관계는 스키마 스냅샷에 있고 여기엔 동작만 둔다. (→ Schema/PassageSchema.swift)
//

import Foundation
import SwiftData

// nonisolated: 모델 동작도 SwiftData 내부 스레드에서 불릴 수 있다(→ Schema/PassageSchemaV1.swift 주석).
nonisolated extension SessionPhoto {
    convenience init(data: Data? = nil, session: ReadingSession? = nil) {
        self.init()
        self.data = data
        self.session = session
    }
}
