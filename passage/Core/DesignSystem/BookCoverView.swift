//
//  BookCoverView.swift
//  passage
//
//  책 표지(원격 URL) 표시. 검색 결과가 준 coverRemoteURL을 AsyncImage로 로드.
//  URL이 없거나 실패하면 은은한 자리표시.
//

import SwiftUI

struct BookCoverView: View {
    let urlString: String?

    var body: some View {
        Group {
            if let urlString, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .empty:
                        placeholder.overlay { ProgressView() }
                    case .failure:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .clipShape(.rect(cornerRadius: Theme.Radius.sm, style: .continuous))
    }

    private var placeholder: some View {
        Rectangle()
            .fill(.quaternary)
            .overlay {
                Image(systemName: "book.closed")
                    .foregroundStyle(.secondary)
            }
    }
}
