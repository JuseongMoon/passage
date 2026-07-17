//
//  PassStackView.swift
//  passage
//
//  "패스"들이 보딩패스처럼 쌓인 스택. 맨 앞(front) 한 장만 펼쳐지고, 위로 최대 2장이
//  헤더만 내밀며 겹쳐 보인다. 아래 책들은 화면 하단에서 헤더만 살짝 내민다.
//  위/아래로 쓸어(swipe) front를 옮기거나, 접힌 카드의 헤더를 눌러 펼친다.
//

import SwiftUI

/// 스택 배치 상수(패스 카드와 공유). 목업 비례에 맞춘 고정 메트릭. (→ Docs/DECISIONS 재구성 결정)
enum PassLayout {
    static let headerHeight: CGFloat = 46
    static let row: CGFloat = 40             // 헤더 간 간격(46보다 작아 살짝 겹침)
    static let frontTop: CGFloat = 118       // 위로 2장 peek 했을 때 front의 상단
    static let topMin: CGFloat = 38          // 위 헤더가 더는 올라가지 않는 하한(추가 알약 자리)
    static let hPadding: CGFloat = 16
    static let topCornerRadius: CGFloat = 22
    static let notchRadius: CGFloat = 11     // 절취선 양옆 반원 노치(티켓 실루엣)
    static let bottomAnchorInset: CGFloat = 112   // 하단에서 첫 아래-헤더가 내미는 높이
    static let belowStep: CGFloat = 48
    static let swipeThreshold: CGFloat = 34
}

struct PassStackView: View {
    let passes: [PassPresentation]
    @Binding var front: Int

    let onStartSession: (Int) -> Void
    let onViewJourney: (Int) -> Void
    let onDelete: (Int) -> Void
    let onSetPageCount: (Int) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let height = geo.size.height
            let front = clampedFront

            ZStack(alignment: .top) {
                ForEach(Array(passes.enumerated()), id: \.element.id) { index, pass in
                    PassCardView(
                        pass: pass,
                        isFront: index == front,
                        expandedMinHeight: max(0, height - topOffset(for: index, front: front, height: height)),
                        onOpen: { step(to: index) },
                        onStartSession: { onStartSession(index) },
                        onViewJourney: { onViewJourney(index) },
                        onDelete: { onDelete(index) },
                        onSetPageCount: { onSetPageCount(index) }
                    )
                    .offset(y: topOffset(for: index, front: front, height: height))
                    // zIndex는 원래 보간이 안 돼(순간 전환) 카드가 겹칠 때 draw order가 툭 바뀐다.
                    // depth를 Animatable로 프레임마다 보간 → 카드가 교차하는 시점에 순서가 바뀜.
                    .modifier(DepthEffect(depth: zIndex(for: index, front: front)))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .contentShape(.rect)
            .gesture(stackDrag)
            .clipped()
        }
    }

    // MARK: 배치 계산

    /// front를 항상 유효 범위로.
    private var clampedFront: Int {
        guard !passes.isEmpty else { return 0 }
        return min(max(0, front), passes.count - 1)
    }

    private func topOffset(for index: Int, front: Int, height: CGFloat) -> CGFloat {
        if index <= front {
            // 위쪽 그룹: 헤더들이 상단에 쌓인다(front 위로 최대 2장 peek).
            let peekAbove = CGFloat(2 - min(front, 2))
            return max(
                PassLayout.topMin,
                PassLayout.frontTop - peekAbove * PassLayout.row + CGFloat(index - front) * PassLayout.row
            )
        } else {
            // 아래쪽 그룹: 하단에서 헤더만 내민다(멀수록 아래로 내려가 화면 밖으로).
            let belowRank = CGFloat(index - front - 1)
            return height - PassLayout.bottomAnchorInset + belowRank * PassLayout.belowStep
        }
    }

    /// 위 그룹은 아래일수록 앞(front가 그 중 최상단). 아래 그룹은 front 위로 하단에서 peek —
    /// front에 가까울수록 앞. (목업: 뒤 패스들이 앞 패스 하단에 겹쳐 보임)
    private func zIndex(for index: Int, front: Int) -> Double {
        index <= front
            ? Double(index)
            : Double(front) + Double(passes.count - index)
    }

    // MARK: 제스처 / 이동

    private var stackDrag: some Gesture {
        DragGesture(minimumDistance: 12)
            .onEnded { value in
                let dy = value.translation.height
                guard abs(dy) > PassLayout.swipeThreshold else { return }
                step(by: dy > 0 ? -1 : 1)   // 위로 쓸면(dy<0) 다음(아래) 책, 아래로 쓸면 이전(위) 책
            }
    }

    private func step(to index: Int) {
        withAnimation(motion) { front = clamp(index) }
    }

    private func step(by delta: Int) {
        withAnimation(motion) { front = clamp(clampedFront + delta) }
    }

    private func clamp(_ value: Int) -> Int {
        min(max(0, value), max(0, passes.count - 1))
    }

    private var motion: Animation? {
        reduceMotion ? nil : .snappy(duration: 0.28)
    }
}

/// zIndex를 애니메이션 가능하게 만든다. `.zIndex()`는 값이 보간되지 않아 front 전환 순간
/// draw order가 툭 바뀌는데(깜빡임), depth를 `animatableData`로 두면 프레임마다 보간되어
/// 재적용된다 → 겹친 카드들이 실제로 교차하는 시점에 순서가 부드럽게 바뀐다.
private struct DepthEffect: ViewModifier, Animatable {
    var depth: Double
    var animatableData: Double {
        get { depth }
        set { depth = newValue }
    }
    func body(content: Content) -> some View {
        content.zIndex(depth)
    }
}
