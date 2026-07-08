//
//  BarcodeProgressView.swift
//  passage
//
//  독서 진행률을 바코드처럼 얇은 세로 틱으로 표현한다. (목업 "독서 진행률")
//  읽은 만큼의 틱이 잉크색으로 켜진다 — 목표/압박이 아니라 "여기까지 왔다"는 조용한 표식.
//

import SwiftUI

struct BarcodeProgressView: View {
    let progress: Double     // 0...1
    let percent: Int

    private let tickCount = 48
    private let tickHeight: CGFloat = 44

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            HStack {
                Text("독서 진행률")
                    .font(.system(size: 12))
                    .foregroundStyle(PassagePalette.ink)
                Spacer()
                Text("\(percent)%")
                    .font(.system(size: 12).monospacedDigit())
                    .foregroundStyle(PassagePalette.ink)
            }

            HStack(spacing: 0) {
                ForEach(0..<tickCount, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1, style: .continuous)
                        .fill(index < litCount ? PassagePalette.ink : PassagePalette.progressOff)
                        .frame(width: 2, height: tickHeight)
                        .frame(maxWidth: .infinity)   // 균등 분산(space-between 느낌)
                }
            }
            .accessibilityElement()
            .accessibilityLabel("독서 진행률")
            .accessibilityValue("\(percent)퍼센트")
        }
    }

    private var litCount: Int {
        let clamped = min(1, max(0, progress))
        return Int((Double(tickCount) * clamped).rounded())
    }
}

#Preview {
    VStack(spacing: 24) {
        BarcodeProgressView(progress: 0.62, percent: 62)
        BarcodeProgressView(progress: 0.08, percent: 8)
        BarcodeProgressView(progress: 1.0, percent: 100)
    }
    .padding()
    .background(PassagePalette.cardBody)
}
