//
//  PhotoThumbnail.swift
//  passage
//
//  Data(장소 사진)를 이미지로 표시. 비어있거나 디코드 실패 시 은은한 자리표시.
//

import SwiftUI
import UIKit

struct PhotoThumbnail: View {
    let data: Data?

    var body: some View {
        if let data, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else {
            Rectangle()
                .fill(.quaternary)
                .overlay {
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }
        }
    }
}
