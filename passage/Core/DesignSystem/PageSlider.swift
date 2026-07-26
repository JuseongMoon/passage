//
//  PageSlider.swift
//  passage
//
//  "어디까지 읽었는지"를 잡는 슬라이더. 숫자 키패드 대신 책 전체를 한 줄로 보여주고 그 위에서 짚는다.
//  트랙 전체가 책 한 권(1…전체 페이지)이라 내 위치가 책의 어디쯤인지 눈으로 읽힌다.
//
//  - `anchor`   이번 구간의 출발점(지난 세션 도달점 / 이 세션 시작 페이지). 여기서부터 채워진다.
//  - `lowerLimit` 조작 하한. 종료 입력에서 시작 페이지 뒤로 못 가게 한다 → 시작 > 끝 역전이 불가능해진다.
//  - 큰 숫자를 누르면 직접 입력 — 300쪽짜리 책에서 트랙 1pt ≈ 1페이지라 손가락으로 짚기 어려운
//    정확한 페이지는 숫자로 넣는다. (접근성: 손 조작이 어려운 경우의 대체 경로이기도 하다)
//
//  전체 페이지 수를 모르면 상한이 없어 트랙을 그릴 수 없다 → 이 뷰를 쓰지 않는다(호출부에서 분기).
//

import SwiftUI

struct PageSlider: View {
    @Binding var page: Int
    /// 이 숫자가 무엇인지("시작 페이지" / "도착 페이지"). 접근성 문구·직접 입력 알림 제목에도 쓰인다.
    let label: String
    /// 전체 페이지 수(상한). 1 이상이어야 한다.
    let total: Int
    /// 이번 구간의 출발점. nil이면 이전 구간 없이 1부터.
    var anchor: Int? = nil
    /// 조작 하한. nil이면 1까지 내려갈 수 있다.
    var lowerLimit: Int? = nil
    let swatch: PassagePalette.Swatch
    /// 트랙 아래 보조 문구(선택).
    var caption: String? = nil

    @State private var isEditing = false
    @State private var draft = ""

    private let trackHeight: CGFloat = 6
    private let knobSize: CGFloat = 26

    // MARK: 파생값 — 전부 안전 범위로 정규화해서 쓴다(레거시 데이터가 범위를 뒤집는 것을 막는다).

    /// 상한. 최소 1페이지는 되어야 트랙이 성립한다.
    private var upper: Int { max(1, total) }

    /// 하한. 상한을 넘지 않게 한 번 더 조인다.
    private var lower: Int { min(max(1, lowerLimit ?? 1), upper) }

    /// 표시용 출발점(이전 구간의 끝).
    private var anchorPage: Int { min(max(1, anchor ?? lower), upper) }

    private var current: Int { allowed(page) }

    private var percent: Int {
        Int(((Double(current) / Double(upper)) * 100).rounded())
    }

    /// 값을 조작 가능한 범위로 조인다.
    private func allowed(_ value: Int) -> Int {
        min(max(value, lower), upper)
    }

    // MARK: 본문

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            valueHeader
            slider
            bounds
            if let caption {
                Text(caption)
                    .font(.system(size: 12))
                    .foregroundStyle(swatch.dim)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .alert(label, isPresented: $isEditing) {
            TextField("페이지", text: $draft)
                .keyboardType(.numberPad)
            Button("확인") { commitDraft() }
            Button("취소", role: .cancel) { }
        } message: {
            Text(verbatim: "\(lower)–\(upper) 사이의 페이지를 입력하세요.")
        }
    }

    /// 라벨 + 현재 페이지(누르면 직접 입력) + 전체 대비 위치.
    /// 한 줄에 세 요소라 큰 Dynamic Type에서는 좁아지므로, 그때는 퍼센트를 아래 줄로 내린다.
    private var valueHeader: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xs) {
                labelText
                valueButton
                Spacer(minLength: Theme.Spacing.xs)
                percentText
            }
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xs) {
                    labelText
                    valueButton
                }
                percentText
            }
        }
    }

    /// 이 숫자가 무엇인지 — 34pt 숫자가 주인공이도록 한 단계 낮춘 위계.
    private var labelText: some View {
        Text(label)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(swatch.dim)
            .lineLimit(1)
    }

    private var percentText: some View {
        Text(verbatim: "\(upper)쪽 중 \(percent)%")
            .font(.system(size: 13, weight: .medium).monospacedDigit())
            .foregroundStyle(swatch.dim)
            .lineLimit(1)
    }

    private var valueButton: some View {
        Button {
            draft = String(current)
            isEditing = true
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                // verbatim — 페이지는 수량이 아니라 번호다. 로케일 천 단위 쉼표("1,428")를 넣지 않는다.
                Text(verbatim: "\(current)")
                    .font(.system(size: 34, weight: .semibold).monospacedDigit())
                Text("p")
                    .font(.system(size: 17, weight: .semibold))
            }
            .lineLimit(1)
            .foregroundStyle(swatch.ink)
            .padding(.horizontal, Theme.Spacing.xs)
            .padding(.vertical, Theme.Spacing.xxs)
            .background(swatch.ink.opacity(0.08), in: .rect(cornerRadius: Theme.Radius.sm, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label) 직접 입력")
        .accessibilityValue("\(current)쪽")
    }

    /// 3구간 트랙 — [1…anchor] 이전에 읽은 곳 · [anchor…현재] 이번에 읽은 곳 · [현재…끝] 남은 곳.
    private var slider: some View {
        Track(
            current: current,
            anchorPage: anchorPage,
            upper: upper,
            knobSize: knobSize,
            trackHeight: trackHeight,
            swatch: swatch,
            onScrub: { position in
                let raw = Int((Double(upper - 1) * position).rounded()) + 1
                let next = allowed(raw)
                if next != page { page = next }
            }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue("\(upper)쪽 중 \(current)쪽")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: page = allowed(current + 1)
            case .decrement: page = allowed(current - 1)
            @unknown default: break
            }
        }
        // 끝(완독 지점)에 닿는 순간에만 가볍게 — 매 페이지 진동은 소란스럽다.
        .sensoryFeedback(.impact(weight: .light), trigger: current) { _, new in new == upper }
    }

    /// 트랙 양 끝 눈금 — 트랙은 언제나 책 전체(1…전체)를 그리므로 눈금도 그 양 끝이다.
    /// (조작 하한은 눈금이 아니라 채워진 '이전에 읽은 곳' 구간과 캡션이 알려준다.)
    private var bounds: some View {
        HStack {
            Text(verbatim: "1p")
            Spacer()
            Text(verbatim: "\(upper)p")
        }
        .font(.system(size: 11).monospacedDigit())
        .foregroundStyle(swatch.dim)
    }

    /// 직접 입력 확정 — 범위 밖 숫자는 조여서 반영하고, 빈 값·잘못된 값은 무시한다.
    private func commitDraft() {
        guard let value = Int(draft.filter(\.isNumber)) else { return }
        page = allowed(value)
    }
}

// MARK: - 트랙

/// 트랙 본체. 페이지(Int) ↔ 좌표(CGFloat) 변환이 섞이면 타입 추론이 무거워지므로 뷰를 분리하고
/// 좌표 계산은 전부 CGFloat로 명시한다. 제스처는 트랙 위 비율(0…1)만 올려보내고 페이지 환산은 상위가 한다.
private struct Track: View {
    let current: Int
    let anchorPage: Int
    let upper: Int
    let knobSize: CGFloat
    let trackHeight: CGFloat
    let swatch: PassagePalette.Swatch
    let onScrub: (Double) -> Void

    var body: some View {
        GeometryReader { geo in
            let usable: CGFloat = max(1, geo.size.width - knobSize)
            let anchorX: CGFloat = position(anchorPage, usable: usable)
            let currentX: CGFloat = position(current, usable: usable)
            let fillStart: CGFloat = min(anchorX, currentX)
            let fillWidth: CGFloat = abs(currentX - anchorX)

            ZStack(alignment: .leading) {
                Capsule()                                    // 남은 곳
                    .fill(swatch.ink.opacity(0.14))
                    .frame(height: trackHeight)

                Capsule()                                    // 이전에 읽은 곳
                    .fill(swatch.ink.opacity(0.42))
                    .frame(width: anchorX, height: trackHeight)

                Capsule()                                    // 이번에 읽은 곳
                    .fill(swatch.ink)
                    .frame(width: fillWidth, height: trackHeight)
                    .offset(x: fillStart)

                if anchorPage > 1 {                          // 이번 구간이 시작된 자리
                    Rectangle()
                        .fill(swatch.base)
                        .frame(width: 2, height: trackHeight + 8)
                        .offset(x: anchorX - 1)
                }

                Circle()                                     // 핸들
                    .fill(swatch.ink)
                    .frame(width: knobSize, height: knobSize)
                    .overlay(Circle().stroke(swatch.base, lineWidth: 3))
                    .shadow(color: .black.opacity(0.18), radius: 3, y: 1)
                    .offset(x: currentX - knobSize / 2)
            }
            .frame(maxHeight: .infinity, alignment: .center)
            .contentShape(.rect)
            .gesture(
                // minimumDistance 0 → 트랙을 톡 누르면 그 지점으로 바로 간다.
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        onScrub(Double((value.location.x - knobSize / 2) / usable))
                    }
            )
        }
        .frame(height: 44)          // 트랙은 얇지만 터치 영역은 넉넉하게
    }

    /// 페이지 → 트랙 위 x좌표(핸들 중심).
    private func position(_ page: Int, usable: CGFloat) -> CGFloat {
        guard upper > 1 else { return knobSize / 2 + usable }
        let bounded = min(max(page, 1), upper)
        let ratio = CGFloat(bounded - 1) / CGFloat(upper - 1)
        return knobSize / 2 + usable * ratio
    }
}

// MARK: - Preview

#Preview("페이지 슬라이더") {
    struct Host: View {
        @State private var ended = 200
        @State private var ready = 88
        @State private var long = 1428          // 네 자리 페이지(전집·합본) — 헤더가 한 줄에 들어가는지

        var body: some View {
            let swatch = PassagePalette.swatches[0]
            VStack(spacing: Theme.Spacing.xl) {
                PageSlider(
                    page: $ended,
                    label: "도착 페이지",
                    total: 340,
                    anchor: 150,
                    lowerLimit: 150,
                    swatch: swatch,
                    caption: "어디까지 읽었는지 옮겨 주세요 · 숫자를 눌러 직접 입력할 수 있어요"
                )
                PageSlider(
                    page: $ready,
                    label: "시작 페이지",
                    total: 340,
                    anchor: 88,
                    swatch: swatch,
                    caption: "지난번 88p까지 읽었어요 · 숫자를 눌러 직접 입력할 수 있어요"
                )
                PageSlider(
                    page: $long,
                    label: "도착 페이지",
                    total: 1892,
                    anchor: 1200,
                    lowerLimit: 1200,
                    swatch: swatch
                )
            }
            .padding(Theme.Spacing.lg)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(swatch.base)
        }
    }
    return Host()
}
