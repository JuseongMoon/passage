//
//  PassageScreenHeader.swift
//  passage
//
//  화면 상단 커스텀 헤더(웜 팔레트). 서재·독서여정·설정이 공유해 톤을 통일한다.
//  시스템 내비게이션 바 대신 사용 — 대형 잉크 타이틀 + 선택적 워드마크/서브타이틀/트레일링 액션.
//  (→ DECISIONS #18 톤 통일)
//

import SwiftUI

struct PassageScreenHeader<Trailing: View>: View {
    /// 상단 워드마크(예: "Passage"). 서재 홈 시그니처 — 다른 화면은 비운다.
    var eyebrow: String? = nil
    let title: String
    var subtitle: String? = nil
    /// 우측 상단 액션(예: 저널의 "회고"). 없으면 EmptyView.
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                if let eyebrow {
                    Text(eyebrow)
                        .font(.system(size: 19, weight: .light))
                        .foregroundStyle(PassagePalette.ink)
                }
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text(title)
                        .font(.system(size: 28))
                        .foregroundStyle(PassagePalette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .accessibilityAddTraits(.isHeader)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundStyle(PassagePalette.inkMuted)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            trailing()
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.top, Theme.Spacing.sm)
        .padding(.bottom, Theme.Spacing.xs)
    }
}

// 트레일링 액션이 없는 화면을 위한 편의 이니셜라이저.
extension PassageScreenHeader where Trailing == EmptyView {
    init(eyebrow: String? = nil, title: String, subtitle: String? = nil) {
        self.init(eyebrow: eyebrow, title: title, subtitle: subtitle) { EmptyView() }
    }
}

#Preview {
    ZStack {
        PassagePalette.appBg.ignoresSafeArea()
        VStack(spacing: Theme.Spacing.xl) {
            PassageScreenHeader(
                eyebrow: "Passage",
                title: "나의 서재",
                subtitle: "현재 4권의 책을 읽고 있어요"
            )
            PassageScreenHeader(title: "독서여정", subtitle: "12개의 기억") {
                Text("회고")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(PassagePalette.ink)
                    .padding(.vertical, 6)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .background(PassagePalette.cardBody, in: .capsule)
            }
            PassageScreenHeader(title: "설정")
            Spacer()
        }
    }
}
