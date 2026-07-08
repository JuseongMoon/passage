//
//  CircularTimerView.swift
//  passage
//
//  독서 세션의 원형 시계 타이머. 60개의 틱이 시계 눈금처럼 둘러싸고,
//  경과한 분만큼 따뜻한 색으로 켜진다. 가운데에 경과 시간을 표시한다.
//

import SwiftUI

struct CircularTimerView: View {
    /// 일시정지 구간을 제외하고 이미 누적된 경과 초.
    let accumulated: TimeInterval
    /// 현재 러닝 구간의 시작 시각(일시정지 중·미시작이면 nil).
    /// 표시 경과 = accumulated + (now - runningSince). 전부 Sendable 값이라
    /// TimelineView가 어느 스레드에서 평가해도 MainActor 상태(컨트롤러)에 닿지 않는다.
    let runningSince: Date?
    /// 틱을 켤지 여부(ready 단계에서는 false).
    var active: Bool = true
    var diameter: CGFloat = 280

    private let tickCount = 60

    /// 주어진 시각의 경과 초(순수 계산). ReadingSessionController.elapsed(now:)와 같은 식.
    /// `nonisolated`: TimelineView content가 렌더 스레드에서 평가돼도 안전하도록.
    private nonisolated func elapsed(at now: Date) -> TimeInterval {
        accumulated + (runningSince.map { max(0, now.timeIntervalSince($0)) } ?? 0)
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let seconds = elapsed(at: context.date)
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
        CircularTimerView(accumulated: 0, runningSince: nil, active: false, diameter: 240)
        CircularTimerView(accumulated: 1_530, runningSince: nil, active: true, diameter: 240)  // 25:30
    }
    .padding()
    .background(PassagePalette.appBg)
}
