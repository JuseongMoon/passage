//
//  PassageSchema.swift
//  passage
//
//  현재 스키마 버전을 가리키는 단 한 곳. 앱 코드는 버전을 모르고 `Book`·`ReadingSession`만 쓴다.
//  (→ ARCHITECTURE §5 · DECISIONS #22 · #31)
//
//  새 버전 추가 절차:
//  1. `PassageSchemaTests.writeFixture()`로 **현재 버전**의 픽스처 스토어를 먼저 만든다.
//  2. `PassageSchemaV<n>.swift`를 복사해 `V<n+1>`을 만들고 그 안에서만 스키마를 바꾼다(이전 스냅샷은 동결).
//  3. 아래 typealias를 새 버전으로 옮기고, `schemas`에 추가, `stages`에 이전→새 단계를 잇는다.
//  두 버전이 같은 클래스를 공유하면 "Duplicate version checksums" **잡을 수 없는 예외**로 런치가 죽는다 —
//  스토어 폴백도 못 막는다. `PassageSchemaTests`가 이를 막는다.
//

import SwiftData

typealias PassageSchemaLatest = PassageSchemaV1

typealias Book = PassageSchemaLatest.Book
typealias ReadingSession = PassageSchemaLatest.ReadingSession
typealias Place = PassageSchemaLatest.Place
typealias Quote = PassageSchemaLatest.Quote
typealias SessionPhoto = PassageSchemaLatest.SessionPhoto

nonisolated enum PassageMigrationPlan: SchemaMigrationPlan {
    /// 오래된 순. 마지막이 `PassageSchemaLatest`.
    static var schemas: [any VersionedSchema.Type] {
        [PassageSchemaV1.self]
    }

    /// 인접한 두 버전마다 한 단계. CloudKit Production 스키마는 추가만 허용되므로 단계는 대개 `.lightweight`다.
    static var stages: [MigrationStage] {
        []
    }
}
