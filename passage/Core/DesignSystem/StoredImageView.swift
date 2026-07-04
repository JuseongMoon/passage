//
//  StoredImageView.swift
//  passage
//
//  ImageStore 참조(id)로 로컬 이미지를 비동기 로드해 표시. 로딩 중엔 은은한 자리표시.
//

import SwiftUI
import UIKit

struct StoredImageView: View {
    let ref: String
    @Environment(AppDependencies.self) private var dependencies
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(.quaternary)
                    .overlay { ProgressView() }
            }
        }
        .task(id: ref) {
            guard let data = try? await dependencies.imageStore.loadData(id: ref) else { return }
            image = UIImage(data: data)
        }
    }
}
