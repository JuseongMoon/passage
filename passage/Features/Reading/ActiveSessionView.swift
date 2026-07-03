//
//  ActiveSessionView.swift
//  passage
//
//  읽는 중 화면. 조용한 경과 시간과 종료 버튼만. (Calm·Minimal)
//  전역에서 활성 세션이 있으면 RootView가 이 화면을 덮어 띄운다.
//

import SwiftUI
import UIKit   // UIKeyboardType

struct ActiveSessionView: View {
    @Environment(ReadingSessionController.self) private var controller
    let session: ReadingSession
    @State private var endPageText: String = ""

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()

            VStack(spacing: Theme.Spacing.sm) {
                Text("읽는 중")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(session.book?.title ?? "제목 없는 책")
                    .font(.title2)
                    .fontDesign(.serif)
                    .multilineTextAlignment(.center)
            }

            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(elapsed(now: context.date).clockString)
                    .font(.system(size: 60, weight: .light).monospacedDigit())
                    .contentTransition(.numericText())
            }

            Spacer()

            VStack(spacing: Theme.Spacing.md) {
                TextField("종료 페이지 (선택)", text: $endPageText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 220)

                Button {
                    controller.stop(endPage: Int(endPageText))
                } label: {
                    Text("독서 종료").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("취소", role: .destructive) {
                    controller.cancel()
                }
                .font(.subheadline)
                .padding(.top, Theme.Spacing.xs)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .padding()
        .interactiveDismissDisabled()
    }

    private func elapsed(now: Date) -> TimeInterval {
        max(0, now.timeIntervalSince(session.startDate))
    }
}
