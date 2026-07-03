//
//  Theme.swift
//  passage
//
//  디자인 토큰. 매직 넘버 대신 이 값을 사용한다. (→ Docs/UI_GUIDE.md)
//

import SwiftUI

enum Theme {
    /// 4pt 그리드 간격.
    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16      // 기본
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    /// 연속 곡률 반경.
    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
    }
}

extension View {
    /// 표준 카드 배경(연속 곡률 + 은은한 재질). Calm·Minimal 기본 컨테이너.
    /// 순수 SwiftUI 재질을 사용해 플랫폼 색상(UIKit) 의존을 피한다.
    func passageCard(cornerRadius: CGFloat = Theme.Radius.lg) -> some View {
        self
            .padding(Theme.Spacing.md)
            .background(
                .regularMaterial,
                in: .rect(cornerRadius: cornerRadius, style: .continuous)
            )
    }
}
