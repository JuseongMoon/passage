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
import UIKit

struct ReadingSessionView: View {
    @Environment(ReadingSessionController.self) private var controller
    @Environment(AppDependencies.self) private var dependencies

    // 페이지는 슬라이더로 잡는다 — 값이 항상 범위 안이므로 문자열이 아니라 정수로 다룬다.
    @State private var startPage = 1
    @State private var endPage = 1
    @State private var totalPageText = ""            // 전체 페이지 수를 모를 때만 쓰는 입력
    @State private var editingStartPage = false
    @State private var startPageDraft = ""
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

    private enum Field { case total, place, note, address }

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
            Text(currentBook?.displayTitle ?? "")
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

    /// 시작 페이지도 슬라이더로 고른다 — 앱을 쓰기 전부터 읽던 책이면 지금 위치로 옮겨야 하므로
    /// 지난 도달점(anchor)을 참고점으로 두되 앞뒤로 자유롭게 움직일 수 있다(하한 없음).
    private var readyRows: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            infoRow("독서 시간", value: TimeInterval(0).clockString)
            if let total = bookTotal {
                PageSlider(
                    page: $startPage,
                    label: "시작 페이지",
                    total: total,
                    anchor: suggestedStartPage,
                    swatch: swatch,
                    caption: readyCaption
                )
            } else {
                totalPageRow
            }
        }
    }

    private var readyCaption: String {
        if let suggested = suggestedStartPage {
            return "지난번 \(suggested)p까지 읽었어요 · 숫자를 눌러 직접 입력할 수 있어요"
        }
        return "이미 읽고 있던 책이면 지금 페이지로 옮겨 주세요 · 숫자를 눌러 직접 입력할 수 있어요"
    }

    private var readyButton: some View {
        primaryPill("읽기 시작하기", systemImage: "play.fill") {
            controller.confirmStart(startPage: bookTotal == nil ? nil : startPage)
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
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    infoRow("독서 시간", value: (controller.endedSession?.duration ?? 0).clockString)
                    if let total = bookTotal {
                        startPageRow
                        PageSlider(
                            page: $endPage,
                            label: "도착 페이지",     // '종료'는 책의 마지막으로 읽힌다 → 여정(시작↔도착) 은유로
                            total: total,
                            anchor: startPage,
                            lowerLimit: startPage,      // 시작 페이지 뒤로는 못 간다 → 역전 자체가 불가능
                            swatch: swatch,
                            caption: "어디까지 읽었는지 옮겨 주세요 · 숫자를 눌러 직접 입력할 수 있어요"
                        )
                    } else {
                        totalPageRow
                    }
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
        .alert("시작 페이지", isPresented: $editingStartPage) {
            TextField("페이지", text: $startPageDraft)
                .keyboardType(.numberPad)
            Button("확인") { commitStartPage() }
            Button("취소", role: .cancel) { }
        } message: {
            Text("이번 독서를 시작한 페이지예요.")
        }
        .task(id: controller.endedSession?.id) {
            prefillEndedPages()
            await autofillLocationIfPossible()
        }
    }

    /// 시작 페이지 — 세션에 이미 확정된 값이지만, 잘못 잡았다면 여기서 고칠 수 있다(탭 → 직접 입력).
    private var startPageRow: some View {
        Button {
            startPageDraft = String(startPage)
            editingStartPage = true
        } label: {
            VStack(spacing: 6) {
                HStack {
                    Text("시작 페이지")
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(swatch.ink)
                    Spacer()
                    Text(verbatim: "\(startPage)p")     // 페이지는 번호 — 천 단위 쉼표를 넣지 않는다
                        .font(.system(size: 19, weight: .medium).monospacedDigit())
                        .foregroundStyle(swatch.ink)
                    Image(systemName: "pencil")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(swatch.dim)
                }
                rowDivider
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("시작 페이지 \(startPage)쪽. 눌러서 수정")
    }

    /// 전체 페이지 수를 모르면 트랙의 상한이 없어 슬라이더를 그릴 수 없다 → 여기서 바로 채운다.
    /// 채우는 즉시 슬라이더로 바뀌고, 건너뛰면 이번 기록은 페이지 없이 저장된다(강요하지 않는다).
    private var totalPageRow: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text("전체 페이지 수")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(swatch.ink)
                Spacer()
                TextField("", text: $totalPageText, prompt: Text("예: 320").foregroundStyle(swatch.dim))
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .font(.system(size: 19, weight: .medium).monospacedDigit())
                    .foregroundStyle(swatch.ink)
                    .focused($focusedField, equals: .total)
                    .frame(maxWidth: 110)
                Button("확인") { applyTotalPageCount() }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(swatch.ink)
                    .opacity(canApplyTotalPage ? 1 : 0.35)
                    .disabled(!canApplyTotalPage)
            }
            rowDivider
            Text("전체 페이지 수를 알려주면 어디까지 읽었는지 슬라이더로 표시할 수 있어요.")
                .font(.system(size: 12))
                .foregroundStyle(swatch.dim)
                .fixedSize(horizontal: false, vertical: true)
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
                .accessibilityElement()
                .accessibilityLabel("선택한 장소 지도")
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

    /// 슬라이더의 상한. 전체 페이지 수를 모르면 nil → 슬라이더 대신 전체 페이지 수 입력을 보여준다.
    private var bookTotal: Int? {
        PageRules.limit(currentBook?.totalPageCount)
    }

    /// 페이지 값을 이 책의 범위 안으로 조인다.
    private func clampToBook(_ value: Int) -> Int {
        guard let total = bookTotal else { return max(1, value) }
        return min(max(1, value), total)
    }

    private var canApplyTotalPage: Bool {
        PageRules.normalizedTotal(Int(totalPageText.filter(\.isNumber))) != nil
    }

    /// 전체 페이지 수 확정 — 상한이 생기는 순간 슬라이더로 바뀌므로 현재 값들도 새 범위로 맞춘다.
    private func applyTotalPageCount() {
        guard let book = currentBook,
              let total = PageRules.normalizedTotal(Int(totalPageText.filter(\.isNumber)))
        else { return }
        controller.setTotalPageCount(total, for: book)
        focusedField = nil
        startPage = min(max(1, startPage), total)
        endPage = min(max(startPage, endPage), total)
    }

    /// 시작 페이지 직접 입력 확정. 끝 페이지가 그보다 앞이면 함께 끌어올린다(역전 방지).
    private func commitStartPage() {
        guard let value = Int(startPageDraft.filter(\.isNumber)), value > 0 else { return }
        startPage = clampToBook(value)
        if endPage < startPage { endPage = startPage }
    }

    private var startPageDisplay: String {
        controller.activeSession?.startPage.map { "\($0)" } ?? "—"
    }

    /// 진행 중 표시 경과(초). 일시정지면 runningSince가 nil이라 누적값에서 멈춘다.
    private func liveElapsed(_ now: Date) -> TimeInterval {
        controller.timerAccumulated + (controller.timerRunningSince.map { max(0, now.timeIntervalSince($0)) } ?? 0)
    }

    /// 슬라이더 초기 위치 — 지난 도달점(없으면 1)에서 출발한다.
    private func prefillStartPage() {
        guard !didPrefillStartPage else { return }
        didPrefillStartPage = true
        let base = suggestedStartPage
            ?? controller.activeSession?.startPage
            ?? controller.endedSession?.startPage
            ?? 1
        startPage = clampToBook(base)
        endPage = max(startPage, clampToBook(controller.endedSession?.endPage ?? startPage))
        totalPageText = currentBook?.totalPageCount.map(String.init) ?? ""
    }

    /// 종료 단계 진입 시 세션에 확정된 시작 페이지를 반영하고, 끝 페이지를 그 위에서 출발시킨다.
    private func prefillEndedPages() {
        guard let session = controller.endedSession else { return }
        startPage = clampToBook(session.startPage ?? startPage)
        endPage = max(startPage, clampToBook(session.endPage ?? startPage))
    }

    /// 전체 페이지 수를 끝내 모르면 페이지 없이 저장한다(슬라이더가 없었으므로 기록할 값도 없다).
    private func saveEnded() {
        let hasPages = bookTotal != nil
        controller.finishEndedInline(
            startPage: hasPages ? startPage : nil,
            endPage: hasPages ? endPage : nil,
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

/// 표지 히어로 — 풀블리드로 표지를 폭에 맞춰 채우고, 넘치는 세로 영역을 위→아래로 1분 주기로
/// 천천히 왕복(순환)하며 보여준다(정지된 가운데 크롭 대신 살아 움직이는 히어로). 로드 전/실패/
/// 표지 없음이면 cover→base 그라데이션으로 아래 색 섹션에 자연스럽게 이어지게 한다.
/// 종횡비(오버플로)를 알아야 팬 범위가 정확하므로 AsyncImage 대신 UIImage로 직접 로드한다.
/// BookCoverView는 항상 작은 곡률로 클립하므로, 상단 풀블리드 히어로는 전용으로 그린다.
private struct BookCoverHero: View {
    let urlString: String?
    let top: Color
    let bottom: Color

    @State private var image: UIImage?
    @State private var didFail = false

    // 위→아래 한 방향 60초: 앞 panRamp초 가속 · 가운데 panCruise초 등속 · 끝 panRamp초 감속.
    // 양 끝(맨 위·맨 아래)에서 속도가 0이라 방향 전환이 튀지 않고 베지어처럼 부드럽게 뒤집힌다.
    private static let panRamp: Double = 5                     // 앞/뒤 이징 구간(초)
    private static let panCruise: Double = 50                  // 가운데 등속 구간(초)
    private static let panSpeed = 1.0 / (panRamp + panCruise)  // 등속 속도(pan/초)
    private static let panV1 = 0.5 * panSpeed * panRamp        // 가속이 끝나는 지점(= 감속 시작의 대칭점)
    private static let panV2 = 1.0 - panV1

    private var fallback: some View {
        LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let image {
                    panningImage(image, in: geo.size)
                } else if didFail || urlString == nil {
                    fallback
                } else {
                    fallback.overlay { ProgressView().tint(.white) }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .task(id: urlString) { await load() }
    }

    /// 표지를 폭에 맞춰 채우고(세로로 넘침), 넘치는 만큼만 위→아래로 팬한다. 가로는 가운데 정렬.
    /// 양 끝은 감속/가속(속도 0)해 방향 전환이 부드럽고, 가운데는 등속. (KeyframeAnimator 순환)
    private func panningImage(_ uiImage: UIImage, in size: CGSize) -> some View {
        let imgW = max(uiImage.size.width, 1)
        let imgH = max(uiImage.size.height, 1)
        let scale = max(size.width / imgW, size.height / imgH)   // fill(짧은 변 기준)
        let renderedW = imgW * scale
        let renderedH = imgH * scale
        let overflowY = max(0, renderedH - size.height)
        let insetX = (renderedW - size.width) / 2
        let base = Image(uiImage: uiImage)
            .resizable()
            .frame(width: renderedW, height: renderedH)
        return Group {
            if overflowY > 0 {
                base.keyframeAnimator(initialValue: 0.0) { view, pan in
                    view.offset(x: -insetX, y: -overflowY * CGFloat(pan))   // 가로 가운데 + 세로 팬
                } keyframes: { _ in
                    KeyframeTrack(\.self) {
                        // 위→아래: 가속(끝속도 = 등속) → 등속 → 감속(끝속도 0, 맨 아래에서 정지)
                        CubicKeyframe(Self.panV1, duration: Self.panRamp, startVelocity: 0, endVelocity: Self.panSpeed)
                        LinearKeyframe(Self.panV2, duration: Self.panCruise)
                        CubicKeyframe(1.0, duration: Self.panRamp, startVelocity: Self.panSpeed, endVelocity: 0)
                        // 아래→위: 대칭. 시작·끝 속도 0이라 양 끝 방향 전환이 매끄럽고 루프 이음새도 연속.
                        CubicKeyframe(Self.panV2, duration: Self.panRamp, startVelocity: 0, endVelocity: -Self.panSpeed)
                        LinearKeyframe(Self.panV1, duration: Self.panCruise)
                        CubicKeyframe(0.0, duration: Self.panRamp, startVelocity: -Self.panSpeed, endVelocity: 0)
                    }
                }
            } else {
                base.offset(x: -insetX)                          // 넘침 없음 → 가로 가운데 고정
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .clipped()
    }

    private func load() async {
        didFail = false
        image = nil
        guard let urlString, let url = URL(string: urlString) else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let ui = UIImage(data: data) { image = ui } else { didFail = true }
        } catch {
            didFail = true
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
