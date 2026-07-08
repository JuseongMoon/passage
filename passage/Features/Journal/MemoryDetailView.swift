//
//  MemoryDetailView.swift
//  passage
//
//  하나의 기억(세션) 상세 — 책 · 읽은 날 · 시간 · 페이지 · 장소 · 사진.
//  서재와 같은 웜 팔레트 톤(appBg·표지 히어로·cardBody 카드 섹션). (→ DECISIONS #18)
//

import SwiftUI
import SwiftData

struct MemoryDetailView: View {
    let session: ReadingSession
    @State private var editingNote = false

    var body: some View {
        ZStack {
            PassagePalette.appBg.ignoresSafeArea()

            List {
                heroSection
                recordSection
                thoughtSection
                placeSection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)   // 시스템 리스트 배경 숨김 → appBg 노출
            .foregroundStyle(PassagePalette.ink)
            .tint(PassagePalette.warmAccent)
        }
        .navigationTitle("기억")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $editingNote) {
            NoteEditorView(session: session)
        }
    }

    // MARK: 히어로 (표지 + 제목 + 저자)

    private var heroSection: some View {
        Section {
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                BookCoverView(urlString: session.book?.coverRemoteURL)
                    .frame(width: 64, height: 96)
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text(session.book?.title ?? "제목 없는 책")
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

    // MARK: 장소

    @ViewBuilder private var placeSection: some View {
        if let place = session.place {
            Section {
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
                if let photos = place.photos, !photos.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Theme.Spacing.xs) {
                            ForEach(photos.sorted { $0.dateAdded < $1.dateAdded }) { photo in
                                PhotoThumbnail(data: photo.data)
                                    .frame(width: 140, height: 140)
                                    .clipShape(.rect(cornerRadius: Theme.Radius.md, style: .continuous))
                            }
                        }
                        .padding(.vertical, Theme.Spacing.xxs)
                    }
                }
            } header: {
                sectionHeader("장소")
            }
            .listRowBackground(PassagePalette.cardBody)
        }
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
