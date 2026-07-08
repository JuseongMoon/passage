//
//  JournalView.swift
//  passage
//
//  저널 — 독서 기억의 타임라인. 책/장소 렌즈로 묶어 본다. 탭하면 Memory 상세.
//

import SwiftUI
import SwiftData

struct JournalView: View {
    @Query(
        filter: #Predicate<ReadingSession> { $0.endDate != nil },
        sort: \ReadingSession.startDate,
        order: .reverse
    ) private var sessions: [ReadingSession]

    @State private var lens: JournalLens = .book
    @State private var showingReflection = false

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    ContentUnavailableView {
                        Label("아직 남긴 독서가 없어요", systemImage: "book.closed")
                    } description: {
                        Text("독서를 마치면 이곳에 기억이 쌓여요.")
                    }
                } else {
                    VStack(spacing: 0) {
                        Picker("보기", selection: $lens) {
                            ForEach(JournalLens.allCases) { lens in
                                Text(lens.label).tag(lens)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.xs)

                        List {
                            ForEach(MemoryOrganizer.grouped(sessions, by: lens)) { group in
                                Section(group.title) {
                                    ForEach(group.sessions) { session in
                                        NavigationLink {
                                            MemoryDetailView(session: session)
                                        } label: {
                                            MemoryRow(session: session, showsBook: lens == .place)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("독서여정")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingReflection = true } label: {
                        Label("회고", systemImage: "sparkles")
                    }
                }
            }
            .sheet(isPresented: $showingReflection) {
                ReflectionView()
            }
        }
    }
}

#Preview {
    JournalView()
        .withPreviewEnvironment()
}
