//
//  PageRules.swift
//  passage
//
//  페이지 값의 유일한 규칙. 입력 UI(PageSlider)는 애초에 범위 밖을 만들 수 없지만,
//  저장 계층·레거시 데이터 교정·인용구 페이지가 같은 기준을 공유해야 하므로 여기 모은다.
//  전체 페이지 수(`Book.totalPageCount`)가 상한의 유일한 권위다 — 페이지는 언제나 그에 종속된다.
//
//  순수 값 계산이라 뷰·모델과 분리해 단위 테스트로 검증한다. (→ PageRulesTests)
//

import Foundation

enum PageRules {
    /// 유효한 상한. 전체 페이지 수를 모르거나 0 이하면 상한 없음(nil) — 이때는 자유 입력이다.
    nonisolated static func limit(_ total: Int?) -> Int? {
        guard let total, total > 0 else { return nil }
        return total
    }

    /// 전체 페이지 수 자체를 다듬는다. 0 이하는 "모름"(nil)으로 본다.
    nonisolated static func normalizedTotal(_ total: Int?) -> Int? {
        limit(total)
    }

    /// 페이지 하나를 규칙에 맞춘다.
    /// nil은 nil(페이지 미기록은 허용된 상태) · 0 이하는 nil · 상한을 알면 그 위로는 잘라낸다.
    nonisolated static func clamped(_ page: Int?, total: Int?) -> Int? {
        guard let page, page > 0 else { return nil }
        guard let limit = limit(total) else { return page }
        return min(page, limit)
    }

    /// 세션 한 건의 시작·끝을 함께 다듬는다.
    /// 각각을 clamp한 뒤, 둘 다 있는데 역전(시작 > 끝)이면 서로 바꾼다 — 값을 버리지 않는다.
    /// (슬라이더 입력에서는 역전이 발생할 수 없고, 레거시 데이터 교정을 위해 남겨둔 규칙이다.)
    nonisolated static func normalized(
        start: Int?,
        end: Int?,
        total: Int?
    ) -> (start: Int?, end: Int?) {
        let s = clamped(start, total: total)
        let e = clamped(end, total: total)
        guard let s, let e, s > e else { return (s, e) }
        return (e, s)
    }
}
