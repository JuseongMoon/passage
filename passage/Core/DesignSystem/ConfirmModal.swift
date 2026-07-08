//
//  ConfirmModal.swift
//  passage
//
//  파괴적 동작 확인용 커스텀 모달(딤 백드롭 + 중앙 카드). (목업 삭제 확인)
//  되돌릴 수 없는 삭제에만 쓴다 — 담백하게. (→ UI_GUIDE §10)
//

import SwiftUI

extension View {
    /// `item`이 있으면 확인 모달을 띄운다. 취소/확인(파괴적) 두 버튼.
    /// - title: item으로부터 제목 문구를 만든다(예: "'제목'을(를) 삭제할까요?").
    func passageConfirmModal<Item: Identifiable>(
        item: Binding<Item?>,
        title: @escaping (Item) -> String,
        message: String,
        confirmTitle: String,
        onConfirm: @escaping (Item) -> Void
    ) -> some View {
        modifier(ConfirmModalModifier(
            item: item, title: title, message: message,
            confirmTitle: confirmTitle, onConfirm: onConfirm
        ))
    }
}

private struct ConfirmModalModifier<Item: Identifiable>: ViewModifier {
    @Binding var item: Item?
    let title: (Item) -> String
    let message: String
    let confirmTitle: String
    let onConfirm: (Item) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.overlay {
            ZStack {
                if let item {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .onTapGesture { self.item = nil }
                    card(item)
                        .transition(reduceMotion
                            ? .opacity
                            : .scale(scale: 0.92).combined(with: .opacity))
                }
            }
            .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: item == nil)
        }
    }

    private func card(_ item: Item) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(title(item))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(PassagePalette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(message)
                .font(.system(size: 12.5))
                .foregroundStyle(PassagePalette.inkMuted)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: Theme.Spacing.xs) {
                Button { self.item = nil } label: {
                    Text("취소")
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .foregroundStyle(PassagePalette.ink)
                        .background(Capsule().stroke(PassagePalette.ink.opacity(0.25), lineWidth: 1.5))
                }
                .buttonStyle(.plain)

                Button {
                    onConfirm(item)
                    self.item = nil
                } label: {
                    Text(confirmTitle)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .foregroundStyle(.white)
                        .background(PassagePalette.danger, in: .capsule)
                }
                .buttonStyle(.plain)
            }
            .font(.system(size: 13.5, weight: .semibold))
            .padding(.top, Theme.Spacing.sm)
        }
        .padding(Theme.Spacing.lg)
        .background(PassagePalette.appBg, in: .rect(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.3), radius: 30, x: 0, y: 12)
        .padding(.horizontal, Theme.Spacing.xl)
    }
}

private struct ConfirmPreviewItem: Identifiable { let id = 0; let title = "작별하지 않는다" }

#Preview {
    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
        Text("서재").font(.system(size: 28)).foregroundStyle(PassagePalette.ink)
        Text("현재 3권의 책을 읽고 있어요").foregroundStyle(PassagePalette.inkMuted)
        Spacer()
    }
    .padding(Theme.Spacing.lg)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(PassagePalette.appBg)
    .passageConfirmModal(
        item: .constant(ConfirmPreviewItem()),
        title: { "'\($0.title)'을(를) 삭제할까요?" },
        message: "이 책의 모든 독서 기록과 여정이 함께 삭제되며, 되돌릴 수 없어요.",
        confirmTitle: "삭제하기",
        onConfirm: { _ in }
    )
}
