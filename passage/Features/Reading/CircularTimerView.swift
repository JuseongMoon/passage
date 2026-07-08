//
//  CircularTimerView.swift
//  passage
//
//  독서 세션의 원형 시계 타이머. 60개의 틱이 시계 눈금처럼 둘러싸고,
//  경과한 분만큼 따뜻한 색으로 켜진다. 가운데에 경과 시간을 표시한다.
//

import SwiftUI

struct CircularTimerView: View {
    /// 주어진 시각 기준 경과 초. (컨트롤러의 elapsed를 넘긴다)
    let elapsed: (Date) -> TimeInterval
    /// 틱을 켤지 여부(ready 단계에서는 false).
    var active: Bool = true
    var diameter: CGFloat = 280

    private let tickCount = 60

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let seconds = elapsed(context.date)
            let lit = active ? min(tickCount, Int(seconds / 60)) : 0

            ZStack {
                ForEach(0..<tickCount, id: \.self) { index in
                    Capsule()
                        .fill(index < lit ? PassagePalette.warmAccent : PassagePalette.progressOff)
                        .frame(width: 2, height: 20)
                        .offset(y: -(diameter / 2 - 22))
                        .rotationEffect(.degrees(Double(index) / Double(tickCount) * 360))
                }

                Text(seconds.clockString)
                    .font(.system(size: diameter * 0.18, weight: .light).monospacedDigit())
                    .foregroundStyle(PassagePalette.ink)
                    .contentTransition(.numericText())
            }
            .frame(width: diameter, height: diameter)
            .accessibilityElement()
            .accessibilityLabel("경과 시간")
            .accessibilityValue(seconds.clockString)
        }
    }
}

#Preview {
    VStack(spacing: 40) {
        CircularTimerView(elapsed: { _ in 0 }, active: false, diameter: 240)
        CircularTimerView(elapsed: { _ in 1_530 }, active: true, diameter: 240)  // 25:30
    }
    .padding()
    .background(PassagePalette.appBg)
}
