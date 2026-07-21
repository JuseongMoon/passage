//
//  ReadingSessionView.swift
//  passage
//
//  독서 세션 오버레이. 준비(ready) → 진행/일시정지(running/paused) → 종료(ended)를 한 화면에서 흐른다.
//  세 단계가 같은 "보딩 스텁" 레이아웃을 공유한다 — 상단에 책 표지 히어로, 그 아래 책 색(swatch.base)
//  섹션에 제목·저자와 label·value 행(독서 시간·시작/끝 페이지·장소)을 얹고, 하단에 CTA를 둔다.
//  종료 후 저장하면 기존 "어디서 읽으셨나요?" 장소 화면으로 이어진다. (Passage Home v2 목업)
//

import SwiftUI
import SwiftData
import CoreLocation

struct ReadingSessionView: View {
    @Environment(ReadingSessionController.self) private var controller
    @Environment(AppDependencies.self) private var dependencies

    @State private var startPageText = ""
    @State private var endPageText = ""
    @State private var placeText = ""
    @State private var noteText = ""
    @State private var addressText = ""                       // 장소 = 현재 위치 주소(수정·검색 가능)
    @State private var searchResults: [PlaceSearchResult] = []
    @State private var isSearching = false
    @State private var placeCoord: CLLocationCoordinate2D?
    @State private var placeAddress: String?
    @State private var locationAutofilled = false
    @State private var didAutofill = false
    @State private var didPrefillStartPage = false
    @FocusState private var focusedField: Field?

    private enum Field { case start, end, place, note, address }

    /// 표지 히어로 높이(상태바 밑까지 확장 포함).
    private let heroHeight: CGFloat = 300

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // 화면 전체를 책 색으로. 빈 영역 탭 → 키보드 내림(numberPad엔 return 키가 없음).
            swatch.base
                .ignoresSafeArea()
                .contentShape(.rect)
                .onTapGesture { focusedField = nil }

            VStack(spacing: 0) {
                heroCover
                    .frame(height: heroHeight)
                    .frame(maxWidth: .infinity)
                    .clipped()
                coloredSection
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .ignoresSafeArea(edges: .top)   // 히어로만 상태바 밑까지, 하단 CTA는 안전영역 존중

            closeButton
                .padding(.trailing, Theme.Spacing.md)
                .padding(.top, Theme.Spacing.xs)
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

    // MARK: 표지 히어로

    private var heroCover: some View {
        BookCoverHero(urlString: currentBook?.coverRemoteURL, top: swatch.cover, bottom: swatch.base)
    }

    private var closeButton: some View {
        Button { controller.cancelReading() } label: {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(Color.black.opacity(0.28), in: .circle)
        }
        .accessibilityLabel("닫기")
    }

    // MARK: 책 색 섹션 (단계별 본문)

    @ViewBuilder
    private var coloredSection: some View {
        switch controller.phase {
        case .ready:
            stubLayout { readyRows } cta: { readyButton }
        case .running, .paused:
            stubLayout { runningRows } cta: { runningButtons }
        case .ended:
            endedSection
        case .none:
            EmptyView()
        }
    }

    /// 준비·진행 공통 레이아웃 — 제목/저자 + 행들 + (스페이서) + 하단 CTA. 화면을 가득 채운다.
    private func stubLayout<Rows: View, CTA: View>(
        @ViewBuilder rows: () -> Rows,
        @ViewBuilder cta: () -> CTA
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            titleBlock
            rows()
            Spacer(minLength: Theme.Spacing.lg)
            cta()
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.top, Theme.Spacing.lg)
        .padding(.bottom, Theme.Spacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            Text(currentBook?.title ?? "")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(swatch.ink)
                .lineLimit(2)
            if let author = currentBook?.author, !author.isEmpty {
                Text(author.uppercased())
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(swatch.dim)
                    .lineLimit(1)
            }
        }
    }

    // MARK: ready

    private var readyRows: some View {
        VStack(spacing: Theme.Spacing.lg) {
            infoRow("독서 시간", value: TimeInterval(0).clockString)
            if let suggested = suggestedStartPage {
                infoRow("시작 페이지", value: "\(suggested)")
            } else {
                editableRow("시작 페이지", text: $startPageText, placeholder: "1", field: .start)
            }
        }
    }

    private var readyButton: some View {
        primaryPill("읽기 시작하기", systemImage: "play.fill") {
            controller.confirmStart(startPage: Int(startPageText))
        }
    }

    // MARK: running / paused

    private var runningRows: some View {
        VStack(spacing: Theme.Spacing.lg) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                infoRow("독서 시간", value: liveElapsed(context.date).clockString)
            }
            infoRow("시작 페이지", value: startPageDisplay)
        }
    }

    private var runningButtons: some View {
        HStack(spacing: Theme.Spacing.sm) {
            outlinePill(
                controller.isPaused ? "다시 시작" : "일시정지",
                systemImage: controller.isPaused ? "play.fill" : "pause.fill"
            ) {
                if controller.isPaused { controller.resume() } else { controller.pause() }
            }
            filledPill("끝내기", systemImage: "stop.fill") {
                controller.endReading()
            }
        }
    }

    // MARK: ended (스크롤 — 장소·끝 페이지 입력이 키보드와 함께 넘칠 수 있음)

    private var endedSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                titleBlock
                VStack(spacing: Theme.Spacing.lg) {
                    infoRow("독서 시간", value: (controller.endedSession?.duration ?? 0).clockString)
                    editableRow("시작 페이지", text: $startPageText, placeholder: "p.", field: .start)
                    editableRow("끝 페이지", text: $endPageText, placeholder: "p.", field: .end)
                    noteSection
                    placeSection
                }
                primaryPill("저장하기") { saveEnded() }
                    .padding(.top, Theme.Spacing.xs)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.lg)
        }
        .scrollDismissesKeyboard(.interactively)
        .task(id: controller.endedSession?.id) {
            prefillEndedStartPage()
            await autofillLocationIfPossible()
        }
    }

    /// 세션 직후 감상 한 줄(Memory over Productivity — 기록의 깊이). 선택 입력, 비면 저장 안 함.
    private var noteSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("생각")
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(swatch.ink)
            TextField(
                "",
                text: $noteText,
                prompt: Text("오늘 읽으며 남은 생각 (선택)").foregroundStyle(swatch.dim),
                axis: .vertical
            )
            .focused($focusedField, equals: .note)
            .font(.system(size: 16))
            .foregroundStyle(swatch.ink)
            .lineLimit(1...4)
            rowDivider
        }
    }

    /// 장소 = 현재 위치 주소가 기본. 주소를 고쳐 검색하면 드롭다운에서 새 위치를 고를 수 있다.
    private var placeSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.xs) {
                Text("장소")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(swatch.ink)
                Spacer(minLength: Theme.Spacing.xs)
                TextField(
                    "",
                    text: $addressText,
                    prompt: Text(locationAutofilled ? "현재 위치" : "주소 입력").foregroundStyle(swatch.dim)
                )
                .focused($focusedField, equals: .address)
                .autocorrectionDisabled()
                .multilineTextAlignment(.trailing)
                .font(.system(size: 16))
                .foregroundStyle(swatch.ink)
                .submitLabel(.search)
                .onSubmit { searchPlaces() }
                searchButton
            }
            rowDivider
            if !searchResults.isEmpty {
                searchDropdown
            }
            PlaceMiniMap(coordinate: placeCoord)
                .contentShape(.rect)
                .onTapGesture { openMapPlacePicker() }
                .accessibilityElement()
                .accessibilityLabel("지도·최근 장소에서 고르기")
                .accessibilityAddTraits(.isButton)
            HStack {
                Text("장소 태그")
                    .font(.system(size: 16))
                    .foregroundStyle(swatch.ink)
                Spacer(minLength: Theme.Spacing.sm)
                TextField("", text: $placeText, prompt: Text("추가하기").foregroundStyle(swatch.dim))
                    .focused($focusedField, equals: .place)
                    .autocorrectionDisabled()
                    .multilineTextAlignment(.trailing)
                    .font(.system(size: 16))
                    .foregroundStyle(swatch.ink)
            }
            .padding(.top, Theme.Spacing.xxs)
            rowDivider
        }
    }

    private var searchButton: some View {
        Button { searchPlaces() } label: {
            Group {
                if isSearching {
                    ProgressView().controlSize(.small).tint(swatch.ink)
                } else {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(swatch.ink)
                }
            }
            .frame(width: 30, height: 30)
            .background(swatch.ink.opacity(0.14), in: .circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("이 주소로 장소 검색")
    }

    /// 검색 결과 드롭다운 — 고르면 주소·좌표가 그 장소로 바뀐다.
    private var searchDropdown: some View {
        VStack(spacing: 0) {
            ForEach(searchResults) { result in
                Button { selectPlace(result) } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(result.name)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(PassagePalette.ink)
                            .lineLimit(1)
                        if let address = result.roadAddress ?? result.address, !address.isEmpty {
                            Text(address)
                                .font(.system(size: 12))
                                .foregroundStyle(PassagePalette.inkMuted)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, Theme.Spacing.xs)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                if result.id != searchResults.last?.id {
                    Divider().overlay(PassagePalette.hairline)
                }
            }
        }
        .background(PassagePalette.field, in: .rect(cornerRadius: Theme.Radius.md, style: .continuous))
    }

    // MARK: 행·버튼 구성요소

    /// label(좌) ←→ value(우) + 하단 헤어라인.
    private func infoRow(_ label: String, value: String) -> some View {
        VStack(spacing: 6) {
            HStack {
                Text(label)
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(swatch.ink)
                Spacer()
                Text(value)
                    .font(.system(size: 19, weight: .medium).monospacedDigit())
                    .foregroundStyle(swatch.ink)
            }
            rowDivider
        }
    }

    /// label(좌) ←→ 입력(우) + 하단 헤어라인.
    private func editableRow(_ label: String, text: Binding<String>, placeholder: String, field: Field) -> some View {
        VStack(spacing: 6) {
            HStack {
                Text(label)
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(swatch.ink)
                Spacer()
                TextField("", text: text, prompt: Text(placeholder).foregroundStyle(swatch.dim))
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .font(.system(size: 19, weight: .medium).monospacedDigit())
                    .foregroundStyle(swatch.ink)
                    .focused($focusedField, equals: field)
                    .frame(maxWidth: 160)
            }
            rowDivider
        }
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(swatch.ink.opacity(0.32))
            .frame(height: 1)
    }

    private func primaryPill(_ title: String, systemImage: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            pillLabel(title, systemImage: systemImage)
                .foregroundStyle(.white)
                .background(PassagePalette.ctaInk, in: .capsule)
        }
        .buttonStyle(.plain)
    }

    private func filledPill(_ title: String, systemImage: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            pillLabel(title, systemImage: systemImage)
                .foregroundStyle(.white)
                .background(PassagePalette.ctaInk, in: .capsule)
        }
        .buttonStyle(.plain)
    }

    private func outlinePill(_ title: String, systemImage: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            pillLabel(title, systemImage: systemImage)
                .foregroundStyle(swatch.ink)
                .background(Capsule().stroke(swatch.ink.opacity(0.5), lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    private func pillLabel(_ title: String, systemImage: String?) -> some View {
        HStack(spacing: Theme.Spacing.xs) {
            if let systemImage {
                Image(systemName: systemImage).font(.system(size: 13, weight: .semibold))
            }
            Text(title)
        }
        .font(.system(size: 16, weight: .semibold))
        .frame(maxWidth: .infinity, minHeight: 52)
    }

    // MARK: 파생값

    private var currentBook: Book? {
        controller.pendingBook ?? controller.activeSession?.book ?? controller.endedSession?.book
    }

    /// 서재 카드와 같은 색을 쓴다 — 표지 대표색이 추출돼 있으면 그 은은한 톤, 없으면 book.id 해시 폴백.
    private var swatch: PassagePalette.Swatch {
        guard let book = currentBook else { return PassagePalette.swatches[0] }
        if let hex = book.coverColorHex, let value = UInt32(hex, radix: 16) {
            return PassagePalette.coverSwatch(hex: value)
        }
        return PassagePalette.swatch(for: book)
    }

    private var suggestedStartPage: Int? {
        controller.pendingBook.flatMap { controller.suggestedStartPage(for: $0) }
    }

    private var startPageDisplay: String {
        controller.activeSession?.startPage.map { "\($0)" } ?? "—"
    }

    /// 진행 중 표시 경과(초). 일시정지면 runningSince가 nil이라 누적값에서 멈춘다.
    private func liveElapsed(_ now: Date) -> TimeInterval {
        controller.timerAccumulated + (controller.timerRunningSince.map { max(0, now.timeIntervalSince($0)) } ?? 0)
    }

    private func prefillStartPage() {
        guard !didPrefillStartPage else { return }
        didPrefillStartPage = true
        if let page = suggestedStartPage
            ?? controller.activeSession?.startPage
            ?? controller.endedSession?.startPage {
            startPageText = String(page)
        }
    }

    /// 종료 단계 진입 시 세션의 시작 페이지를 필드에 반영한다(비어 있을 때만).
    private func prefillEndedStartPage() {
        if startPageText.isEmpty, let start = controller.endedSession?.startPage {
            startPageText = String(start)
        }
    }

    private func saveEnded() {
        controller.finishEndedInline(
            startPage: Int(startPageText),
            endPage: Int(endPageText),
            note: noteText,
            placeName: resolvedPlaceName,
            latitude: placeCoord?.latitude,
            longitude: placeCoord?.longitude,
            address: resolvedAddress
        )
    }

    /// 저장할 장소 이름 — 태그 우선, 없으면 주소(둘 다 비면 장소 없이 저장된다).
    private var resolvedPlaceName: String {
        let tag = placeText.trimmingCharacters(in: .whitespacesAndNewlines)
        return tag.isEmpty ? addressText.trimmingCharacters(in: .whitespacesAndNewlines) : tag
    }

    private var resolvedAddress: String? {
        let address = addressText.trimmingCharacters(in: .whitespacesAndNewlines)
        return address.isEmpty ? placeAddress : address
    }

    /// 주소 필드 내용으로 장소를 검색해 드롭다운에 띄운다.
    private func searchPlaces() {
        let query = addressText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty, !isSearching else { return }
        focusedField = nil
        Task {
            isSearching = true
            let results = (try? await dependencies.placeSearch.search(query: query)) ?? []
            isSearching = false
            searchResults = results
        }
    }

    /// 드롭다운에서 고른 장소로 주소·좌표를 바꾼다.
    private func selectPlace(_ result: PlaceSearchResult) {
        addressText = result.roadAddress ?? result.address ?? result.name
        placeAddress = addressText
        placeCoord = CLLocationCoordinate2D(latitude: result.latitude, longitude: result.longitude)
        if placeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            placeText = result.name          // 태그가 비어 있으면 고른 장소명을 제안
        }
        searchResults = []
        locationAutofilled = false
    }

    /// 지도를 눌러 기존 리치 장소 화면(최근 장소·지도 탭·POI 검색·사진)으로 넘긴다.
    private func openMapPlacePicker() {
        controller.finishEnded(startPage: Int(startPageText), endPage: Int(endPageText), note: noteText)
    }

    /// 위치 권한이 이미 있으면 현재 위치를 reverse-geocode해 장소를 자동 채운다(선택).
    private func autofillLocationIfPossible() async {
        guard controller.phase == .ended, !didAutofill else { return }
        didAutofill = true
        let status = dependencies.location.authorizationStatus
        guard status == .authorizedWhenInUse || status == .authorizedAlways else { return }
        do {
            let coord = try await dependencies.location.currentLocation()
            placeCoord = coord
            let address = try await dependencies.geocoding.reverseGeocode(
                latitude: coord.latitude, longitude: coord.longitude
            )
            placeAddress = address
            if addressText.isEmpty {
                addressText = address        // 장소 기본값 = 현재 위치 주소
                locationAutofilled = true
            }
        } catch {
            // 권한 없음/실패 → 조용히 무시(직접 입력 가능)
        }
    }
}

/// 표지 히어로 — 풀블리드로 표지를 채우고(가운데 크롭) 로드 전/실패/표지 없음이면
/// cover→base 그라데이션으로 아래 색 섹션에 자연스럽게 이어지게 한다.
/// BookCoverView는 항상 작은 곡률로 클립하므로, 상단 풀블리드 히어로는 전용으로 그린다.
private struct BookCoverHero: View {
    let urlString: String?
    let top: Color
    let bottom: Color

    private var fallback: some View {
        LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom)
    }

    var body: some View {
        GeometryReader { geo in
            Group {
                if let urlString, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        case .empty:
                            fallback.overlay { ProgressView().tint(.white) }
                        default:
                            fallback
                        }
                    }
                } else {
                    fallback
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
    }
}

/// 종료 단계의 미니맵 — 실제 네이버 지도를 미리보기로 보여준다(탭하면 리치 장소 화면으로).
/// 프리뷰 용도라 지도 자체 제스처는 끄고(allowsHitTesting=false) 바깥 탭 제스처가 먹도록 한다.
private struct PlaceMiniMap: View {
    let coordinate: CLLocationCoordinate2D?

    private var point: MapPoint? {
        coordinate.map { MapPoint(latitude: $0.latitude, longitude: $0.longitude) }
    }

    var body: some View {
        NaverMapView(selectedPoint: .constant(point))
            .allowsHitTesting(false)
            .frame(height: 192)
            .frame(maxWidth: .infinity)
            .clipShape(.rect(cornerRadius: Theme.Radius.md, style: .continuous))
            .overlay(alignment: .topTrailing) {
                Image(systemName: "map")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(PassagePalette.inkMuted)
                    .padding(6)
                    .background(PassagePalette.field.opacity(0.9), in: .circle)
                    .padding(8)
            }
    }
}

// MARK: - Preview

private struct ReadingSessionPreviewHost: View {
    @State private var container: ModelContainer
    @State private var controller: ReadingSessionController

    init(includePreviousSession: Bool = true, _ configure: (ReadingSessionController, Book) -> Void) {
        let container = PassageModelContainer.makePreview()
        let ctx = container.mainContext
        let book = Book(title: "작별하지 않는다", author: "한강", totalPageCount: 340)
        ctx.insert(book)
        if includePreviousSession {
            let prev = ReadingSession(book: book, startPage: 0)   // 지난 세션(자동 채움용)
            prev.endPage = 88
            prev.endDate = .now
            prev.duration = 3600
            ctx.insert(prev)
        }
        try? ctx.save()
        let controller = ReadingSessionController(modelContext: ctx)
        configure(controller, book)
        _container = State(initialValue: container)
        _controller = State(initialValue: controller)
    }

    var body: some View {
        ReadingSessionView()
            .environment(controller)
            .environment(AppDependencies())
    }
}

#Preview("세션 · 준비(첫 독서)") {
    ReadingSessionPreviewHost(includePreviousSession: false) { controller, book in
        controller.beginReading(book: book)
    }
}

#Preview("세션 · 준비(이어읽기)") {
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

#Preview("세션 · 진행(첫 독서)") {
    ReadingSessionPreviewHost(includePreviousSession: false) { controller, book in
        controller.beginReading(book: book)
        controller.confirmStart(startPage: nil)   // 첫 독서 → 1페이지부터
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
