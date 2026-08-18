//
//  MemoryDetailView.swift
//  passage
//
//  하나의 기억(세션) 상세 — 책 · 읽은 날 · 시간 · 페이지 · 장소 · 사진.
//  서재와 같은 웜 팔레트 톤(appBg·표지 히어로·cardBody 카드 섹션). (→ DECISIONS #18)
//

import SwiftUI
import SwiftData
import PhotosUI

struct MemoryDetailView: View {
    let session: ReadingSession
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var editingNote = false
    @State private var changingPlace = false
    @State private var sessionPendingDelete: ReadingSession?
    @State private var photoItem: PhotosPickerItem?
    @State private var photoPendingDelete: SessionPhoto?

    var body: some View {
        ZStack {
            PassagePalette.appBg.ignoresSafeArea()

            List {
                heroSection
                recordSection
                thoughtSection
                placeSection
                photoSection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)   // 시스템 리스트 배경 숨김 → appBg 노출
            .foregroundStyle(PassagePalette.ink)
            .tint(PassagePalette.warmAccent)
        }
        .navigationTitle("기억")
        .navigationBarTitleDisplayMode(.inline)
        // 잘못 시작해 끝낸 세션을 지울 길이 책 전체 삭제뿐이었다 — 기억 하나만 지운다.
        // 통계·진행률·지도는 세션에서 파생되므로(#2) 지우면 알아서 물러난다.
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) { sessionPendingDelete = session } label: {
                    Image(systemName: "trash")
                }
                .tint(PassagePalette.danger)
                .accessibilityLabel("이 기억 삭제")
            }
        }
        .passageConfirmModal(
            item: $sessionPendingDelete,
            title: { _ in "이 여정 기록을 삭제할까요?" },
            message: "이 세션의 시간·페이지·생각·사진이 함께 사라지며, 되돌릴 수 없어요.",
            confirmTitle: "삭제하기",
            onConfirm: { deleteSession($0) }
        )
        .onChange(of: photoItem) { _, newItem in
            Task { await addPhoto(from: newItem) }
        }
        .passageConfirmModal(
            item: $photoPendingDelete,
            title: { _ in "이 사진을 삭제할까요?" },
            message: "이 기억에서 사진이 사라지며, 되돌릴 수 없어요.",
            confirmTitle: "삭제하기",
            onConfirm: { deletePhoto($0) }
        )
        .sheet(isPresented: $editingNote) {
            NoteEditorView(session: session)
        }
        .sheet(isPresented: $changingPlace) {
            ChangePlaceView(session: session)
        }
    }

    // MARK: 히어로 (표지 + 제목 + 저자)

    private var heroSection: some View {
        Section {
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                BookCoverView(urlString: session.book?.coverRemoteURL)
                    .frame(width: 64, height: 96)
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text(session.book?.displayTitle ?? "제목 없는 책")
                        .font(.title3)
                        .fontDesign(.serif)
                        .fontWeight(.semibold)
                        .foregroundStyle(PassagePalette.ink)
                    if let author = session.book?.author, !author.isEmpty {
                        Text(author)
                            .font(.subheadline)
                            .foregroundStyle(PassagePalette.inkMuted)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, Theme.Spacing.xs)
            .listRowBackground(Color.clear)   // 히어로는 appBg 위에 바로(카드 아님)
            .listRowInsets(EdgeInsets(top: 0, leading: Theme.Spacing.md, bottom: 0, trailing: Theme.Spacing.md))
        }
    }

    // MARK: 기록

    private var recordSection: some View {
        Section {
            LabeledContent("읽은 날", value: session.startDate.formatted(date: .long, time: .shortened))
            LabeledContent("독서 시간", value: session.duration.readableDuration)
            if let pageText {
                LabeledContent("페이지", value: pageText)
            }
        } header: {
            sectionHeader("기록")
        }
        .listRowBackground(PassagePalette.cardBody)
    }

    // MARK: 생각(메모)

    @ViewBuilder private var thoughtSection: some View {
        Section {
            if let note = session.note, !note.isEmpty {
                Text(note)
                    .foregroundStyle(PassagePalette.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("편집") { editingNote = true }
                    .font(.subheadline)
                    .foregroundStyle(PassagePalette.warmAccent)
            } else {
                Button {
                    editingNote = true
                } label: {
                    Label("메모 남기기", systemImage: "square.and.pencil")
                        .foregroundStyle(PassagePalette.warmAccent)
                }
            }
        } header: {
            sectionHeader("생각")
        }
        .listRowBackground(PassagePalette.cardBody)
    }

    // MARK: 사진

    /// 이 세션에서 남긴 사진. 소유자가 세션 하나뿐이라 출처를 나눌 필요가 없다. (→ DECISIONS #27)
    /// 사진 입력은 세션 종료 화면 한 곳뿐이라 그 순간을 놓치면 영영 못 붙였다.
    /// 생각·장소가 나중에 편집되듯 사진도 여기서 더하고 지운다(섹션을 항상 띄워 진입점을 남긴다).
    private var photoSection: some View {
        Section {
            if let photos = session.photos, !photos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.xs) {
                        ForEach(photos.sorted { $0.dateAdded < $1.dateAdded }) { photo in
                            PhotoThumbnail(data: photo.data)
                                .frame(width: 140, height: 140)
                                .clipShape(.rect(cornerRadius: Theme.Radius.md, style: .continuous))
                                .contextMenu {
                                    Button(role: .destructive) { photoPendingDelete = photo } label: {
                                        Label("사진 삭제", systemImage: "trash")
                                    }
                                }
                                .accessibilityLabel("이 세션의 사진")
                        }
                    }
                    .padding(.vertical, Theme.Spacing.xxs)
                }
            }
            PhotosPicker(selection: $photoItem, matching: .images) {
                Label("사진 추가", systemImage: "photo")
                    .foregroundStyle(PassagePalette.warmAccent)
            }
        } header: {
            sectionHeader("사진")
        }
        .listRowBackground(PassagePalette.cardBody)
    }

    // MARK: 장소

    @ViewBuilder private var placeSection: some View {
        Section {
            if let place = session.place {
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xs) {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundStyle(PassagePalette.warmAccent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(place.name)
                            .foregroundStyle(PassagePalette.ink)
                        if let address = place.address, !address.isEmpty {
                            Text(address)
                                .font(.footnote)
                                .foregroundStyle(PassagePalette.inkMuted)
                        }
                    }
                }
                Button("위치 변경") { changingPlace = true }
                    .font(.subheadline)
                    .foregroundStyle(PassagePalette.warmAccent)
            } else {
                Button {
                    changingPlace = true
                } label: {
                    Label("위치 추가", systemImage: "mappin.and.ellipse")
                        .foregroundStyle(PassagePalette.warmAccent)
                }
            }
        } header: {
            sectionHeader("장소")
        }
        .listRowBackground(PassagePalette.cardBody)
    }

    // MARK: 동작

    /// 고른 사진을 이 세션에 붙인다(세션 종료 화면과 같은 SessionPhoto 경로).
    private func addPhoto(from item: PhotosPickerItem?) async {
        guard let item, let data = try? await item.loadTransferable(type: Data.self) else { return }
        modelContext.insert(SessionPhoto(data: data, session: session))
        try? modelContext.save()
        photoItem = nil
    }

    private func deletePhoto(_ photo: SessionPhoto) {
        modelContext.delete(photo)
        try? modelContext.save()
    }

    /// 기억 하나를 지운다. 사진은 cascade로 함께 사라지고, 장소는 nullify라 남는다.
    private func deleteSession(_ session: ReadingSession) {
        modelContext.delete(session)
        try? modelContext.save()
        dismiss()
    }

    // MARK: 헬퍼

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(PassagePalette.inkMuted)
            .textCase(nil)
    }

    private var pageText: String? {
        if let start = session.startPage, let end = session.endPage { return "\(start)–\(end)p" }
        if let end = session.endPage { return "~\(end)p" }
        if let start = session.startPage { return "\(start)p~" }
        return nil
    }
}

#Preview {
    let container = PassageModelContainer.makePreview()
    let ctx = container.mainContext
    let book = Book(title: "작별하지 않는다", author: "한강", totalPageCount: 340)
    let place = Place(name: "연희동 카페", address: "서울 서대문구 연희로 11길 24")
    ctx.insert(book); ctx.insert(place)
    let s = ReadingSession(book: book, startPage: 88)
    s.endPage = 176
    s.duration = 70 * 60
    s.endDate = .now
    s.place = place
    s.note = "한강의 문장은 눈처럼 조용히 쌓인다. 오늘은 특히 한 문단에 오래 머물렀다."
    ctx.insert(s)

    return NavigationStack {
        MemoryDetailView(session: s)
    }
    .modelContainer(container)
}
