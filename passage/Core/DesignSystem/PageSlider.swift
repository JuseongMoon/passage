//
//  PageSlider.swift
//  passage
//
//  "어디까지 읽었는지"를 잡는 슬라이더. 숫자 키패드 대신 책 전체를 한 줄로 보여주고 그 위에서 짚는다.
//  트랙 전체가 책 한 권(1…전체 페이지)이라 내 위치가 책의 어디쯤인지 눈으로 읽힌다.
//
//  세 조각으로 나뉜다 —
//  - `PageValueField`  라벨 + 페이지 숫자(+ 전체 대비 위치). 슬라이더의 머리이면서, 트랙 없이 값만
//                      보여줄 때(독서 중)도 같은 모습 그대로 쓴다.
//  - `PageSlider`      값 하나 + 트랙 하나. 세션 준비(시작 페이지)에서 쓴다.
//  - `PageRangeSlider` 시작·도착을 한 줄에 나란히 두고 트랙 하나로 도착을 잡는다. 세션 종료 입력.
//
//  - `anchor`   이번 구간의 출발점(지난 세션 도달점 / 이 세션 시작 페이지). 여기서부터 채워진다.
//  - 큰 숫자를 누르면 직접 입력 — 300쪽짜리 책에서 트랙 1pt ≈ 1페이지라 손가락으로 짚기 어려운
//    정확한 페이지는 숫자로 넣는다. (접근성: 손 조작이 어려운 경우의 대체 경로이기도 하다)
//
//  전체 페이지 수를 모르면 상한이 없어 트랙을 그릴 수 없다 → 이 뷰를 쓰지 않는다(호출부에서 분기).
//

import SwiftUI

// MARK: - 값 표시

/// 라벨 + 페이지 숫자. 슬라이더의 머리이자, 트랙 없이 값만 남길 때도 쓰는 공통 조각이라
/// 준비 화면에서 본 모습이 독서 중·종료 화면까지 그대로 이어진다.
struct PageValueField: View {
    /// `.large` 단독으로 놓일 때(준비·독서 중) · `.compact` 시작·도착을 한 줄에 나란히 둘 때.
    enum Size { case large, compact }

    /// 이 숫자가 무엇인지("시작 페이지" / "도착 페이지"). 접근성 문구에도 쓰인다.
    let label: String
    let page: Int
    let swatch: PassagePalette.Swatch
    var size: Size = .large
    /// 전체 페이지 수. 주면 "N쪽 중 M%"를 곁들인다(모르면 생략).
    var total: Int? = nil
    /// 숫자를 눌렀을 때 — 직접 입력 경로. nil이면 표시 전용.
    var onEdit: (() -> Void)? = nil

    var body: some View {
        if let total {
            // 한 줄에 세 요소라 큰 Dynamic Type에서는 좁아진다 → 그때는 퍼센트를 아래 줄로 내린다.
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xs) {
                    field
                    Spacer(minLength: Theme.Spacing.xs)
                    percentText(total)
                }
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    field
                    percentText(total)
                }
            }
        } else {
            field
        }
    }

    @ViewBuilder
    private var field: some View {
        if let onEdit {
            Button(action: onEdit) { fieldContent }
                .buttonStyle(.plain)
                .accessibilityLabel("\(label) 직접 입력")
                .accessibilityValue("\(page)쪽")
        } else {
            fieldContent
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(label) \(page)쪽")
        }
    }

    private var fieldContent: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xs) {
            Text(label)
                .font(.system(size: labelSize, weight: .semibold))
                .foregroundStyle(swatch.dim)
                .lineLimit(1)
            numberChip
        }
    }

    /// 숫자가 주인공 — 라벨보다 한 단계 큰 위계로 두고 은은한 판 위에 얹는다.
    private var numberChip: some View {
        HStack(alignment: .firstTextBaseline, spacing: 1) {
            // verbatim — 페이지는 수량이 아니라 번호다. 로케일 천 단위 쉼표("1,428")를 넣지 않는다.
            Text(verbatim: "\(page)")
                .font(.system(size: numberSize, weight: .semibold).monospacedDigit())
            Text("p")
                .font(.system(size: unitSize, weight: .semibold))
        }
        .lineLimit(1)
        .foregroundStyle(swatch.ink)
        .padding(.horizontal, Theme.Spacing.xs)
        .padding(.vertical, Theme.Spacing.xxs)
        .background(swatch.ink.opacity(0.08), in: .rect(cornerRadius: Theme.Radius.sm, style: .continuous))
    }

    private func percentText(_ total: Int) -> some View {
        let upper = max(1, total)
        let bounded = min(max(page, 1), upper)
        let percent = Int(((Double(bounded) / Double(upper)) * 100).rounded())
        return Text(verbatim: "\(upper)쪽 중 \(percent)%")
            .font(.system(size: 13, weight: .medium).monospacedDigit())
            .foregroundStyle(swatch.dim)
            .lineLimit(1)
    }

    private var labelSize: CGFloat { size == .large ? 16 : 15 }
    private var numberSize: CGFloat { size == .large ? 34 : 22 }
    private var unitSize: CGFloat { size == .large ? 17 : 12 }
}

// MARK: - 값 하나 + 트랙 하나

struct PageSlider: View {
    @Binding var page: Int
    /// 이 숫자가 무엇인지("시작 페이지"). 직접 입력 알림 제목에도 쓰인다.
    let label: String
    /// 전체 페이지 수(상한). 1 이상이어야 한다.
    let total: Int
    /// 이번 구간의 출발점. nil이면 이전 구간 없이 1부터.
    var anchor: Int? = nil
    let swatch: PassagePalette.Swatch
    /// 트랙 아래 보조 문구(선택).
    var caption: String? = nil

    @State private var isEditing = false
    @State private var draft = ""

    // MARK: 파생값 — 전부 안전 범위로 정규화해서 쓴다(레거시 데이터가 범위를 뒤집는 것을 막는다).

    /// 상한. 최소 1페이지는 되어야 트랙이 성립한다.
    private var upper: Int { max(1, total) }

    /// 표시용 출발점(이전 구간의 끝).
    private var anchorPage: Int { min(max(1, anchor ?? 1), upper) }

    private var current: Int { allowed(page) }

    /// 값을 조작 가능한 범위로 조인다.
    private func allowed(_ value: Int) -> Int {
        min(max(value, 1), upper)
    }

    // MARK: 본문

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            PageValueField(label: label, page: current, swatch: swatch, total: upper) {
                draft = String(current)
                isEditing = true
            }
            slider
            TrackBounds(leading: "1p", trailing: "\(upper)p", swatch: swatch)
            if let caption {
                TrackCaption(text: caption, swatch: swatch)
            }
        }
        .alert(label, isPresented: $isEditing) {
            TextField("페이지", text: $draft)
                .keyboardType(.numberPad)
            Button("확인") { commitDraft() }
            Button("취소", role: .cancel) { }
        } message: {
            Text(verbatim: "1–\(upper) 사이의 페이지를 입력하세요.")
        }
    }

    /// 3구간 트랙 — [1…anchor] 이전에 읽은 곳 · [anchor…현재] 이번에 읽은 곳 · [현재…끝] 남은 곳.
    private var slider: some View {
        Track(
            current: current,
            anchorPage: anchorPage,
            upper: upper,
            swatch: swatch,
            onScrub: { position in
                let next = allowed(Track.page(at: position, upper: upper))
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

    /// 직접 입력 확정 — 범위 밖 숫자는 조여서 반영하고, 빈 값·잘못된 값은 무시한다.
    private func commitDraft() {
        guard let value = Int(draft.filter(\.isNumber)) else { return }
        page = allowed(value)
    }
}

// MARK: - 시작·도착 한 줄 + 트랙 하나

/// 세션 종료 입력 — 시작·도착을 한 줄에 나란히 두고, 그 아래 트랙 하나로 도착 페이지를 잡는다.
/// 여정의 두 끝이 한눈에 붙어 보이고 세로도 짧아진다(종료 화면은 생각·장소까지 이어지므로).
/// 시작 페이지는 이미 확정된 값이라 숫자를 눌러서만 고친다 — 트랙은 도착 페이지의 것이다.
/// 역전(시작 > 도착)은 구조적으로 불가능하다: 트랙의 하한이 시작 페이지이고,
/// 시작을 도착보다 뒤로 옮기면 도착이 함께 끌려 올라간다.
struct PageRangeSlider: View {
    @Binding var startPage: Int
    @Binding var endPage: Int
    /// 전체 페이지 수(상한). 1 이상이어야 한다.
    let total: Int
    let swatch: PassagePalette.Swatch
    /// 트랙 아래 보조 문구(선택).
    var caption: String? = nil

    @State private var editingStart = false
    @State private var editingEnd = false
    @State private var draft = ""

    private var upper: Int { max(1, total) }
    private var start: Int { min(max(1, startPage), upper) }
    private var end: Int { min(max(endPage, start), upper) }
    private var percent: Int { Int(((Double(end) / Double(upper)) * 100).rounded()) }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            valueRow
            rowDivider
            slider
            // 오른쪽 눈금 자리에 진행률을 겹쳐 둔다 — 상한과 위치를 한 줄로 합쳐 높이를 아낀다.
            TrackBounds(leading: "1p", trailing: "\(upper)쪽 중 \(percent)%", swatch: swatch)
            if let caption {
                TrackCaption(text: caption, swatch: swatch)
            }
        }
        .alert("도착 페이지", isPresented: $editingEnd) {
            TextField("페이지", text: $draft)
                .keyboardType(.numberPad)
            Button("확인") { commitEnd() }
            Button("취소", role: .cancel) { }
        } message: {
            Text(verbatim: "\(start)–\(upper) 사이의 페이지를 입력하세요.")
        }
    }

    /// 시작 ↔ 도착 한 줄. 네 자리 페이지·큰 Dynamic Type으로 좁아지면 두 줄로 접힌다.
    private var valueRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                startField
                Spacer(minLength: Theme.Spacing.xs)
                endField
            }
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                startField
                endField
            }
        }
        // 두 알림을 한 뷰에 겹쳐 달지 않는다(하나만 살아남는다) → 시작 쪽은 이 줄에 붙인다.
        .alert("시작 페이지", isPresented: $editingStart) {
            TextField("페이지", text: $draft)
                .keyboardType(.numberPad)
            Button("확인") { commitStart() }
            Button("취소", role: .cancel) { }
        } message: {
            Text("이번 독서를 시작한 페이지예요.")
        }
    }

    private var startField: some View {
        PageValueField(label: "시작 페이지", page: start, swatch: swatch, size: .compact) {
            draft = String(start)
            editingStart = true
        }
    }

    private var endField: some View {
        PageValueField(label: "도착 페이지", page: end, swatch: swatch, size: .compact) {
            draft = String(end)
            editingEnd = true
        }
    }

    /// 트랙은 도착 페이지의 것 — 시작 페이지가 곧 이번 구간의 출발점이자 조작 하한이다.
    private var slider: some View {
        Track(
            current: end,
            anchorPage: start,
            upper: upper,
            swatch: swatch,
            onScrub: { position in
                let next = allowed(Track.page(at: position, upper: upper))
                if next != endPage { endPage = next }
            }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("도착 페이지")
        .accessibilityValue("\(upper)쪽 중 \(end)쪽")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: endPage = allowed(end + 1)
            case .decrement: endPage = allowed(end - 1)
            @unknown default: break
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: end) { _, new in new == upper }
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(swatch.ink.opacity(0.32))
            .frame(height: 1)
    }

    /// 도착 페이지가 움직일 수 있는 범위 — 시작 페이지 뒤로는 갈 수 없다.
    private func allowed(_ value: Int) -> Int {
        min(max(value, start), upper)
    }

    /// 시작 페이지 직접 입력 확정 — 도착이 그보다 앞이면 함께 끌어올린다(역전 방지).
    private func commitStart() {
        guard let value = Int(draft.filter(\.isNumber)) else { return }
        let next = min(max(value, 1), upper)
        startPage = next
        if endPage < next { endPage = next }
    }

    private func commitEnd() {
        guard let value = Int(draft.filter(\.isNumber)) else { return }
        endPage = allowed(value)
    }
}

// MARK: - 트랙 주변 조각

/// 트랙 양 끝 눈금 — 트랙은 언제나 책 전체(1…전체)를 그리므로 눈금도 그 양 끝이다.
/// (조작 하한은 눈금이 아니라 채워진 '이전에 읽은 곳' 구간과 캡션이 알려준다.)
private struct TrackBounds: View {
    let leading: String
    let trailing: String
    let swatch: PassagePalette.Swatch

    var body: some View {
        HStack {
            Text(verbatim: leading)
            Spacer(minLength: Theme.Spacing.xs)
            Text(verbatim: trailing)
        }
        .font(.system(size: 11).monospacedDigit())
        .foregroundStyle(swatch.dim)
    }
}

private struct TrackCaption: View {
    let text: String
    let swatch: PassagePalette.Swatch

    var body: some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(swatch.dim)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - 트랙

/// 트랙 본체. 페이지(Int) ↔ 좌표(CGFloat) 변환이 섞이면 타입 추론이 무거워지므로 뷰를 분리하고
/// 좌표 계산은 전부 CGFloat로 명시한다. 제스처는 트랙 위 비율(0…1)만 올려보내고 페이지 환산은 상위가 한다.
private struct Track: View {
    let current: Int
    let anchorPage: Int
    let upper: Int
    let swatch: PassagePalette.Swatch
    let onScrub: (Double) -> Void

    private let trackHeight: CGFloat = 6
    private let knobSize: CGFloat = 26

    /// 트랙 위 비율(0…1) → 페이지. 조작 범위로 조이는 것은 호출부의 몫이다.
    static func page(at position: Double, upper: Int) -> Int {
        Int((Double(max(1, upper) - 1) * position).rounded()) + 1
    }

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
        @State private var readyPage = 88
        @State private var start = 150
        @State private var end = 200
        @State private var longStart = 1200     // 네 자리 페이지(전집·합본) — 한 줄에 들어가는지
        @State private var longEnd = 1428

        var body: some View {
            let swatch = PassagePalette.swatches[0]
            ScrollView {
                VStack(spacing: Theme.Spacing.xl) {
                    PageSlider(
                        page: $readyPage,
                        label: "시작 페이지",
                        total: 340,
                        anchor: 88,
                        swatch: swatch,
                        caption: "지난번 88p까지 읽었어요 · 숫자를 눌러 직접 입력할 수 있어요"
                    )
                    PageValueField(label: "시작 페이지", page: readyPage, swatch: swatch, total: 340)
                    PageRangeSlider(
                        startPage: $start,
                        endPage: $end,
                        total: 340,
                        swatch: swatch,
                        caption: "어디까지 읽었는지 옮겨 주세요"
                    )
                    PageRangeSlider(
                        startPage: $longStart,
                        endPage: $longEnd,
                        total: 1892,
                        swatch: swatch
                    )
                }
                .padding(Theme.Spacing.lg)
            }
            .background(swatch.base)
        }
    }
    return Host()
}
