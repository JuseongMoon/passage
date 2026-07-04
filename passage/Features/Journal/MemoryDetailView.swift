//
//  MemoryDetailView.swift
//  passage
//
//  하나의 기억(세션) 상세 — 책 · 읽은 날 · 시간 · 페이지 · 장소 · 사진.
//

import SwiftUI

struct MemoryDetailView: View {
    let session: ReadingSession
    @State private var editingNote = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(session.book?.title ?? "제목 없는 책")
                        .font(.title2)
                        .fontDesign(.serif)
                        .fontWeight(.semibold)
                    if let author = session.book?.author, !author.isEmpty {
                        Text(author).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, Theme.Spacing.xs)
            }

            Section("기록") {
                LabeledContent("읽은 날", value: session.startDate.formatted(date: .long, time: .shortened))
                LabeledContent("독서 시간", value: session.duration.readableDuration)
                if let pageText {
                    LabeledContent("페이지", value: pageText)
                }
            }

            Section("생각") {
                if let note = session.note, !note.isEmpty {
                    Text(note)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button("편집") { editingNote = true }
                        .font(.subheadline)
                } else {
                    Button {
                        editingNote = true
                    } label: {
                        Label("메모 남기기", systemImage: "square.and.pencil")
                    }
                }
            }

            if let place = session.place {
                Section("장소") {
                    Text(place.name)
                    if let address = place.address, !address.isEmpty {
                        Text(address).font(.footnote).foregroundStyle(.secondary)
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
                }
            }
        }
        .navigationTitle("기억")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $editingNote) {
            NoteEditorView(session: session)
        }
    }

    private var pageText: String? {
        if let start = session.startPage, let end = session.endPage { return "\(start)–\(end)p" }
        if let end = session.endPage { return "~\(end)p" }
        if let start = session.startPage { return "\(start)p~" }
        return nil
    }
}
