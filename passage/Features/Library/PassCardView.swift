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

    var body: some View {
        VStack(spacing: 0) {
            header
            if isFront {
                expandedBody
                    .frame(
                        minHeight: max(0, expandedMinHeight - PassLayout.headerHeight),
                        alignment: .top
                    )
                    .frame(maxWidth: .infinity)
                    .background(PassagePalette.cardBody)
            }
        }
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: PassLayout.topCornerRadius,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: PassLayout.topCornerRadius,
                style: .continuous
            )
        )
        .shadow(color: .black.opacity(0.12), radius: 14, x: 0, y: -2)
    }

    // MARK: 헤더 스트립

    private var header: some View {
        HStack(spacing: Theme.Spacing.sm) {
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
            if isFront {
                menuButton
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .frame(height: PassLayout.headerHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(pass.swatch.base)
        .contentShape(.rect)
        .onTapGesture { if !isFront { onOpen() } }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(pass.title), \(pass.headerDate)")
        .accessibilityAddTraits(isFront ? [] : .isButton)
    }

    private var menuButton: some View {
        Menu {
            Button { onViewJourney() } label: {
                Label("전체 여정보기", systemImage: "book.closed")
            }
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
            ticket
            journeys
                .padding(.vertical, Theme.Spacing.md)
            progressSection
            cta
                .padding(.top, Theme.Spacing.lg)
            Spacer(minLength: 0)   // 뉴트럴 배경이 아래를 채운다(목업)
        }
    }

    private var ticket: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(pass.title)
                        .font(.system(size: 18))
                        .foregroundStyle(PassagePalette.ink)
                        .lineLimit(2)
                    if !pass.author.isEmpty {
                        Text(pass.author)
                            .font(.system(size: 12))
                            .foregroundStyle(PassagePalette.ink)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: Theme.Spacing.sm)
                Text(pass.totalDurationText)
                    .font(.system(size: 28, weight: .medium).monospacedDigit())
                    .foregroundStyle(PassagePalette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            cover
        }
        .frame(height: 100)   // 표지 높이에 고정 → 총시간이 표지 하단에 정렬, Spacer가 카드 채움과 경쟁 방지
        .padding(Theme.Spacing.md)
        .overlay(alignment: .top) { DashedLine() }
        .overlay(alignment: .bottom) { DashedLine() }
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
                HStack(alignment: .top, spacing: Theme.Spacing.md) {
                    journeyColumn(pass.recentJourneys[0])
                    if pass.recentJourneys.count > 1 {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(PassagePalette.ink)
                            .padding(.top, 6)
                        journeyColumn(pass.recentJourneys[1])
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
    }

    @ViewBuilder
    private var progressSection: some View {
        Group {
            if let progress = pass.progress, let percent = pass.progressPercent {
                BarcodeProgressView(progress: progress, percent: percent)
            } else {
                // 전체 페이지 수를 모르면 진행률 대신 입력 프롬프트.
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
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
    }

    private var cta: some View {
        Button(action: onStartSession) {
            Text("여정 시작하기")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(PassagePalette.appBg)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(PassagePalette.ink, in: .capsule)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Theme.Spacing.md)
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
