//
//  PassCardView.swift
//  passage
//
//  한 장의 "패스"(보딩패스 카드). 접히면 컬러 헤더 스트립만, 펼치면 티켓·최근 여정·진행률·CTA.
//  컬러는 헤더 스트립과 표지 스와치에만 쓰고, 펼친 바디는 뉴트럴(cardBody)로 차분하게 둔다.
//

import SwiftUI

struct PassCardView: View {
    let pass: PassPresentation
    let isFront: Bool
    /// 펼쳤을 때 바디가 채울 최소 높이(스택 하단까지 확장).
    let expandedMinHeight: CGFloat

    let onOpen: () -> Void
    let onStartSession: () -> Void
    let onViewJourney: () -> Void
    let onDelete: () -> Void
    let onSetPageCount: () -> Void

    /// 절취선 Y(카드 상단 기준) — 하단 CTA 바로 위 파선 위치를 측정해 노치를 맞춘다.
    @State private var tearY: CGFloat = 0
    private static let tearSpace = "passCard"

    var body: some View {
        VStack(spacing: 0) {
            header
            // 바디를 항상 렌더하되 비-front는 높이 0으로 클립한다.
            //  - front 전환 시 이 높이가 0↔펼침으로 '애니메이션'되어 컬러 바디가 팝하지 않고
            //    카드 움직임과 함께 부드럽게 펼쳐지고/접힌다.
            //  - 비-front가 0이라 아래 peek 카드의 바디가 다음 peek을 덮는 문제도 사라진다.
            //  - draw order는 PassStackView의 DepthEffect가 보간해 z 깜빡임을 막는다.
            expandedBody
                .frame(maxWidth: .infinity)
                .frame(
                    height: isFront ? max(0, expandedMinHeight - PassLayout.headerHeight) : 0,
                    alignment: .top
                )
                .clipped()
        }
        // 컬러(swatch.base)를 카드 전체에 한 장으로 깐다 — 헤더/티켓을 각각 칠하면 그 사이
        // 서브픽셀 이음새(seam)가 스와이프 중 벌어졌다 붙는다. 뉴트럴은 expandedBody의 여정
        // 영역에만 얹으므로, 위쪽 컬러 영역은 끊김 없는 한 장이 된다.
        .background(pass.swatch.base)
        // 절취선(파선) 위치를 카드 상단 기준으로 측정하기 위한 좌표 공간.
        .coordinateSpace(.named(Self.tearSpace))
        .clipShape(cardShape)
        // 노치가 바디(크림)·앱 배경과 색이 비슷해도 티켓 실루엣이 또렷하게 읽히도록 얇은 외곽선.
        // 상시 렌더 + opacity: 조건부 삽입/제거면 스와이프 중 stroke가 제자리에 잔류하므로 항상 그린다.
        .overlay {
            cardShape.stroke(PassagePalette.ticketDash, lineWidth: 1)
                .opacity(isFront ? 1 : 0)
        }
        .shadow(color: .black.opacity(0.12), radius: 14, x: 0, y: -2)
        // 접힘(비-front)이면 파선이 사라져 0이 전달되는데, 그때 노치 중심이 0으로 끌려가지 않도록 무시.
        .onPreferenceChange(TearYKey.self) { value in
            if value > 0 { tearY = value }
        }
    }

    /// 항상 같은 concrete 타입(TicketShape)을 쓴다 — AnyShape로 타입을 교체하면 clip/stroke가
    /// 뷰 identity 변경으로 취급돼 스와이프 중 외곽선 잔류·모서리 사각형 깜빡임을 유발한다.
    /// 비-front는 notchRadius 0 → 노치 없는(위 모서리만 둥근) 사각형과 동일.
    private var cardShape: TicketShape {
        TicketShape(
            topRadius: PassLayout.topCornerRadius,
            notchRadius: (isFront && tearY > PassLayout.headerHeight) ? PassLayout.notchRadius : 0,
            notchCenterY: tearY
        )
    }

    // MARK: 헤더 스트립

    private var header: some View {
        HStack(spacing: Theme.Spacing.sm) {
            if isFront {
                // 펼친 카드는 큰 티켓에 제목이 나오므로 스트립엔 메뉴만 둔다(목업).
                // 컬러(swatch.base)는 여기서 티켓 블록까지 그대로 이어진다.
                Spacer(minLength: 0)
                menuButton
            } else {
                Text(pass.title)
                    .font(.system(size: 16))
                    .foregroundStyle(pass.swatch.ink)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: Theme.Spacing.sm)
                Text(pass.headerDate)
                    .font(.system(size: 11))
                    .tracking(0.8)
                    .foregroundStyle(pass.swatch.dim)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .frame(height: PassLayout.headerHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
        .onTapGesture { if !isFront { onOpen() } }
        .accessibilityElement(children: isFront ? .contain : .combine)
        .accessibilityLabel(isFront ? "" : "\(pass.title), \(pass.headerDate)")
        .accessibilityAddTraits(isFront ? [] : .isButton)
    }

    private var menuButton: some View {
        Menu {
            Button(role: .destructive) { onDelete() } label: {
                Label("책 삭제하기", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(pass.swatch.ink)
                .frame(width: 28, height: 28)
                .background(Color.black.opacity(0.14), in: .circle)
        }
        .accessibilityLabel("더 보기")
    }

    // MARK: 펼친 바디

    private var expandedBody: some View {
        VStack(spacing: 0) {
            ticket   // 배경 없음 → 카드 컬러(swatch.base)가 헤더에서 이어져 보인다.
            // 뉴트럴 영역: 여정부터 아래만 cardBody. 컬러/뉴트럴 경계 seam을 피하려
            // 컬러는 카드 전체 배경으로 깔고 여기서만 뉴트럴을 그 위에 얹는다.
            VStack(spacing: 0) {
                journeys
                    .padding(.vertical, Theme.Spacing.md)
                progressSection
                perforation
                cta
                    .padding(.top, Theme.Spacing.sm)
                Spacer(minLength: 0)   // 뉴트럴 배경이 아래를 채운다(목업)
            }
            .frame(maxWidth: .infinity)
            .background(PassagePalette.cardBody)
        }
    }

    /// 절취선 — "여정 시작하기" 바로 위 가로 파선. 자기 중심 Y를 카드 좌표계로 측정해
    /// TicketShape 노치가 정확히 이 높이에 오도록 한다(콘텐츠·Dynamic Type에 따라 가변).
    private var perforation: some View {
        DashedLine()
            .background(
                GeometryReader { geo in
                    Color.clear.preference(
                        key: TearYKey.self,
                        value: geo.frame(in: .named(Self.tearSpace)).midY
                    )
                }
            )
            .padding(.horizontal, PassLayout.notchRadius + 2)
            .padding(.top, Theme.Spacing.lg)
    }

    private var ticket: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(pass.title)
                        .font(.system(size: 18))
                        .foregroundStyle(pass.swatch.ink)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                    if !pass.author.isEmpty {
                        Text(pass.author)
                            .font(.system(size: 12))
                            .foregroundStyle(pass.swatch.dim)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: Theme.Spacing.sm)
                HStack(alignment: .lastTextBaseline, spacing: Theme.Spacing.xs) {
                    Text(pass.totalDurationText)
                        .font(.system(size: 28, weight: .medium).monospacedDigit())
                        .foregroundStyle(pass.swatch.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    if let percent = pass.progressPercent {
                        Text("\(percent)%")
                            .font(.system(size: 15, weight: .medium).monospacedDigit())
                            .foregroundStyle(pass.swatch.dim)
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            cover
        }
        // 표지 높이가 하한 → 짧은 제목은 총시간이 표지 하단에 정렬. 제목이 길면 좌측 열이 아래로 늘어나
        // 여러 줄을 그대로 보여준다(하단 뉴트럴 여백 Spacer가 늘어난 높이를 흡수).
        .frame(minHeight: 100)
        .padding(Theme.Spacing.md)
        // 배경 없음 — 컬러(swatch.base)는 카드 전체 배경 한 장으로 깔려 헤더에서 끊김 없이 이어진다.
    }

    private var cover: some View {
        Group {
            if let url = pass.coverURL, !url.isEmpty {
                BookCoverView(urlString: url)
            } else {
                Rectangle().fill(pass.swatch.cover)
            }
        }
        .frame(width: 76, height: 100)
        .clipShape(.rect(cornerRadius: 2, style: .continuous))
    }

    private var journeys: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            Text("최근 여정기록")
                .font(.system(size: 12))
                .foregroundStyle(PassagePalette.ink)
            if pass.recentJourneys.isEmpty {
                Text("아직 남긴 여정이 없어요")
                    .font(.system(size: 13))
                    .foregroundStyle(PassagePalette.inkMuted)
                    .padding(.top, 2)
            } else {
                // 화살표(→) 방향에 맞춰 왼쪽=이전 여정, 오른쪽=최신 여정.
                // recentJourneys는 최신순([0]=최신)이므로 표시만 뒤집는다.
                HStack(alignment: .top, spacing: Theme.Spacing.md) {
                    if pass.recentJourneys.count > 1 {
                        journeyColumn(pass.recentJourneys[1])   // 이전(왼쪽)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(PassagePalette.ink)
                            .padding(.top, 6)
                        journeyColumn(pass.recentJourneys[0])   // 최신(오른쪽)
                    } else {
                        journeyColumn(pass.recentJourneys[0])
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.Spacing.md)
    }

    private func journeyColumn(_ journey: PassJourney) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(journey.place)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(PassagePalette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(journey.meta)
                .font(.system(size: 12))
                .foregroundStyle(PassagePalette.ink)
                .lineLimit(1)
            Text(journey.date)
                .font(.system(size: 12))
                .foregroundStyle(PassagePalette.inkMuted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // 장소명은 minimumScaleFactor로 축소될 수 있는데, 그러면 카드 offset/height 애니메이션과
        // 레이아웃이 분리돼 "카드를 안 따라가는" 현상이 생긴다. geometryGroup으로 geometry를
        // 하나의 단위로 묶어 부모 애니메이션을 원자적으로 따라가게 한다.
        .geometryGroup()
    }

    // 진행률 % 는 티켓의 총 독서시간 옆에 표시한다. 여기서는 전체 페이지 수를 모를 때만
    // 입력 프롬프트를 둔다(알면 % 가 이미 티켓에 있으므로 이 섹션은 비운다).
    @ViewBuilder
    private var progressSection: some View {
        if pass.progressPercent == nil {
            Button(action: onSetPageCount) {
                HStack {
                    Text("독서 진행률")
                        .font(.system(size: 12))
                        .foregroundStyle(PassagePalette.ink)
                    Spacer()
                    HStack(spacing: 4) {
                        Text("전체 페이지 수 입력")
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PassagePalette.warmAccent)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, Theme.Spacing.md)
        }
    }

    private var cta: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Button(action: onViewJourney) {
                Text("여정보기")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(PassagePalette.ink)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(PassagePalette.appBg, in: .capsule)
                    .overlay { Capsule().stroke(PassagePalette.hairline, lineWidth: 1) }
            }
            .buttonStyle(.plain)
            Button(action: onStartSession) {
                Text("책 읽기")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(PassagePalette.appBg)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(PassagePalette.ink, in: .capsule)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Theme.Spacing.md)
    }
}

/// 보딩패스형 티켓 실루엣. 위 모서리는 둥글게, `notchCenterY`(절취선)에서 좌·우에
/// 반원 노치를 파 "뜯는 티켓" 느낌을 준다. 아래 모서리는 스택에 맞물리도록 각지게 둔다.
private struct TicketShape: Shape {
    var topRadius: CGFloat
    var notchRadius: CGFloat
    var notchCenterY: CGFloat

    // notchRadius·notchCenterY만 보간(topRadius는 상수 → 모서리 사각형 깜빡임을 표현 불가능하게 함).
    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(notchRadius, notchCenterY) }
        set {
            notchRadius = newValue.first
            notchCenterY = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let base = UnevenRoundedRectangle(
            topLeadingRadius: topRadius,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: topRadius,
            style: .continuous
        ).path(in: rect)

        let d = notchRadius * 2
        let left = Path(ellipseIn: CGRect(
            x: rect.minX - notchRadius, y: notchCenterY - notchRadius, width: d, height: d))
        let right = Path(ellipseIn: CGRect(
            x: rect.maxX - notchRadius, y: notchCenterY - notchRadius, width: d, height: d))
        return base.subtracting(left).subtracting(right)
    }
}

/// 티켓 절취선(가로 파선).
private struct DashedLine: View {
    var body: some View {
        GeometryReader { geo in
            Path { path in
                path.move(to: CGPoint(x: 0, y: 0.5))
                path.addLine(to: CGPoint(x: geo.size.width, y: 0.5))
            }
            .stroke(PassagePalette.ticketDash, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        }
        .frame(height: 1)
    }
}

/// 절취선(파선)의 중심 Y를 카드 좌표계로 전달하는 PreferenceKey.
private struct TearYKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
