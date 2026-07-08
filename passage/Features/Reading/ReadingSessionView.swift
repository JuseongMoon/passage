//
//  ReadingSessionView.swift
//  passage
//
//  독서 세션 오버레이. 준비(ready) → 진행/일시정지(running/paused) → 종료(ended) 한 화면에서 흐른다.
//  책 색으로 헤더를 물들이고, 원형 시계 타이머로 조용히 시간을 센다. (목업 Reading session)
//  종료 후 "세션 저장하기"를 누르면 기존 "어디서 읽으셨나요?" 장소 화면으로 이어진다.
//

import SwiftUI
import SwiftData

struct ReadingSessionView: View {
    @Environment(ReadingSessionController.self) private var controller

    @State private var startPageText = ""
    @State private var endPageText = ""
    @State private var didPrefillStartPage = false
    @FocusState private var focusedField: Field?

    private enum Field { case start, end }

    var body: some View {
        ZStack {
            PassagePalette.appBg.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                if let phase = controller.phase {
                    switch phase {
                    case .ready:               readyStep
                    case .running, .paused:    runningStep
                    case .ended:               endedStep
                    }
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("완료") { focusedField = nil }
            }
        }
        .onAppear(perform: prefillStartPage)
        .interactiveDismissDisabled()
    }

    // MARK: 헤더 (책 색)

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text("READING SESSION")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(swatch.dim)
                Spacer()
                Button { controller.cancelReading() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(swatch.ink)
                        .frame(width: 28, height: 28)
                        .background(Color.black.opacity(0.18), in: .circle)
                }
                .accessibilityLabel("닫기")
            }
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                Text(currentBook?.title ?? "")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(swatch.ink)
                    .lineLimit(2)
                Spacer(minLength: Theme.Spacing.sm)
                Text(todayText)
                    .font(.system(size: 12))
                    .foregroundStyle(swatch.dim)
                    .fixedSize()
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.top, Theme.Spacing.md)
        .padding(.bottom, Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(swatch.base)
    }

    // MARK: ready

    private var readyStep: some View {
        VStack(spacing: Theme.Spacing.lg) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                fieldLabel("시작 페이지 (선택)")
                pageField($startPageText, placeholder: suggestedStartPage != nil ? "지난 세션 이어서" : "예: 1")
                    .focused($focusedField, equals: .start)
                if suggestedStartPage != nil {
                    Text("지난 세션에서 읽은 마지막 페이지를 자동으로 가져왔어요")
                        .font(.system(size: 11))
                        .foregroundStyle(PassagePalette.inkFaint)
                }
            }
            Spacer()
            CircularTimerView(elapsed: { _ in 0 }, active: false, diameter: 280)
            Spacer()
            primaryButton("시작", systemImage: "play.fill") {
                controller.confirmStart(startPage: Int(startPageText))
            }
        }
        .padding(Theme.Spacing.lg)
    }

    // MARK: running / paused

    private var runningStep: some View {
        VStack(spacing: Theme.Spacing.lg) {
            HStack {
                fieldLabel("시작 페이지")
                Spacer()
                Text(startPageDisplay)
                    .font(.system(size: 15, weight: .medium).monospacedDigit())
                    .foregroundStyle(PassagePalette.ink)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .frame(height: 48)
            .background(
                PassagePalette.ink.opacity(0.05),
                in: .rect(cornerRadius: Theme.Radius.md, style: .continuous)
            )

            Spacer()
            CircularTimerView(elapsed: { controller.elapsed(now: $0) }, active: true, diameter: 300)
            Spacer()

            HStack(spacing: Theme.Spacing.sm) {
                outlineButton(
                    controller.isPaused ? "다시 시작" : "일시정지",
                    systemImage: controller.isPaused ? "play.fill" : "pause.fill"
                ) {
                    if controller.isPaused { controller.resume() } else { controller.pause() }
                }
                dangerButton("종료", systemImage: "stop.fill") {
                    controller.endReading()
                }
            }
        }
        .padding(Theme.Spacing.lg)
    }

    // MARK: ended

    private var endedStep: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                Text("이번 세션")
                    .font(.system(size: 13))
                    .foregroundStyle(PassagePalette.inkMuted)
                Text((controller.endedSession?.duration ?? 0).clockString)
                    .font(.system(size: 30, weight: .light).monospacedDigit())
                    .foregroundStyle(PassagePalette.ink)
            }

            HStack(spacing: Theme.Spacing.sm) {
                pageColumn("시작 페이지", $startPageText)
                    .focused($focusedField, equals: .start)
                pageColumn("끝 페이지 (선택)", $endPageText)
                    .focused($focusedField, equals: .end)
            }

            Text("저장하면 ‘어디서 읽으셨나요?’에서 장소를 더할 수 있어요")
                .font(.system(size: 11))
                .foregroundStyle(PassagePalette.inkFaint)

            Spacer()
            primaryButton("세션 저장하기") {
                controller.finishEnded(startPage: Int(startPageText), endPage: Int(endPageText))
            }
        }
        .padding(Theme.Spacing.lg)
    }

    // MARK: 구성요소

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(PassagePalette.inkMuted)
    }

    private func pageField(_ text: Binding<String>, placeholder: String) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(.numberPad)
            .font(.system(size: 15).monospacedDigit())
            .foregroundStyle(PassagePalette.ink)
            .padding(.horizontal, Theme.Spacing.md)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .fill(PassagePalette.field)
                    .stroke(PassagePalette.hairline, lineWidth: 1.5)
            )
    }

    private func pageColumn(_ label: String, _ text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            fieldLabel(label)
            pageField(text, placeholder: "p.")
        }
        .frame(maxWidth: .infinity)
    }

    private func primaryButton(_ title: String, systemImage: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            pillLabel(title, systemImage: systemImage)
                .foregroundStyle(PassagePalette.appBg)
                .background(PassagePalette.ink, in: .capsule)
        }
        .buttonStyle(.plain)
    }

    private func dangerButton(_ title: String, systemImage: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            pillLabel(title, systemImage: systemImage)
                .foregroundStyle(.white)
                .background(PassagePalette.danger, in: .capsule)
        }
        .buttonStyle(.plain)
    }

    private func outlineButton(_ title: String, systemImage: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            pillLabel(title, systemImage: systemImage)
                .foregroundStyle(PassagePalette.ink)
                .background(Capsule().stroke(PassagePalette.ink, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    private func pillLabel(_ title: String, systemImage: String?) -> some View {
        HStack(spacing: Theme.Spacing.xs) {
            if let systemImage { Image(systemName: systemImage).font(.system(size: 13, weight: .semibold)) }
            Text(title)
        }
        .font(.system(size: 16, weight: .semibold))
        .frame(maxWidth: .infinity, minHeight: 54)
    }

    // MARK: 파생값

    private var currentBook: Book? {
        controller.pendingBook ?? controller.activeSession?.book ?? controller.endedSession?.book
    }

    private var swatch: PassagePalette.Swatch {
        currentBook.map { PassagePalette.swatch(for: $0) } ?? PassagePalette.swatches[0]
    }

    private var suggestedStartPage: Int? {
        controller.pendingBook.flatMap { controller.suggestedStartPage(for: $0) }
    }

    private var startPageDisplay: String {
        controller.activeSession?.startPage.map { "p. \($0)" } ?? "—"
    }

    private var todayText: String {
        let cal = Calendar.current
        let now = Date()
        let month = cal.component(.month, from: now)
        let day = cal.component(.day, from: now)
        let weekday = cal.component(.weekday, from: now)
        let symbols = ["일", "월", "화", "수", "목", "금", "토"]
        return "\(month)월 \(day)일 (\(symbols[(weekday - 1 + 7) % 7]))"
    }

    private func prefillStartPage() {
        guard !didPrefillStartPage else { return }
        didPrefillStartPage = true
        // ready면 지난 세션의 마지막 페이지, 이미 진행/종료 단계로 들어왔다면 그 세션의 시작 페이지.
        if let page = suggestedStartPage
            ?? controller.activeSession?.startPage
            ?? controller.endedSession?.startPage {
            startPageText = String(page)
        }
    }
}

// MARK: - Preview

private struct ReadingSessionPreviewHost: View {
    @State private var container: ModelContainer
    @State private var controller: ReadingSessionController

    init(_ configure: (ReadingSessionController, Book) -> Void) {
        let container = PassageModelContainer.makePreview()
        let ctx = container.mainContext
        let book = Book(title: "작별하지 않는다", author: "한강", totalPageCount: 340)
        ctx.insert(book)
        let prev = ReadingSession(book: book, startPage: 0)   // 지난 세션(자동 채움용)
        prev.endPage = 88
        prev.endDate = .now
        prev.duration = 3600
        ctx.insert(prev)
        try? ctx.save()
        let controller = ReadingSessionController(modelContext: ctx)
        configure(controller, book)
        _container = State(initialValue: container)
        _controller = State(initialValue: controller)
    }

    var body: some View {
        ReadingSessionView().environment(controller)
    }
}

#Preview("세션 · 준비") {
    ReadingSessionPreviewHost { controller, book in
        controller.beginReading(book: book)
    }
}

#Preview("세션 · 진행") {
    ReadingSessionPreviewHost { controller, book in
        controller.beginReading(book: book)
        controller.confirmStart(startPage: 88)
    }
}

#Preview("세션 · 일시정지") {
    ReadingSessionPreviewHost { controller, book in
        controller.beginReading(book: book)
        controller.confirmStart(startPage: 88)
        controller.pause()
    }
}

#Preview("세션 · 종료") {
    ReadingSessionPreviewHost { controller, book in
        controller.beginReading(book: book)
        controller.confirmStart(startPage: 88)
        controller.endReading()
    }
}
