//
//  BookCoverMarker.swift
//  passage
//
//  지도 마커용 책 표지 이미지 렌더러. 원격 표지(coverRemoteURL)를 받아 둥근 카드 UIImage로 합성한다.
//  표지가 없거나 로드 실패 시 책별 팔레트 색(swatch.base)으로 폴백. book.id로 캐시.
//  마커는 UIImage가 필요한데 BookCoverView는 AsyncImage뿐이라 이 동기/비동기 경로를 따로 둔다.
//
//  MainActor 격리: 드로잉·색 해석을 전부 메인에서 수행(UIColor dynamicProvider off-main 트랩 회피).
//

import UIKit
import SwiftUI

@MainActor
final class BookCoverMarkerRenderer {
    /// 마커 캔버스 크기(그림자 여백 포함). 마커 width/height에 그대로 쓴다.
    static let markerSize = CGSize(width: 48, height: 60)
    private static let inset: CGFloat = 4        // 카드 주변 여백(그림자 공간)
    private static let corner: CGFloat = 6

    private var cache: [UUID: UIImage] = [:]
    private var placeholderCache: [PassagePalette.Swatch: UIImage] = [:]

    /// 즉시 표시용 폴백(표지색 단색 카드). 동기 렌더 + 캐시.
    func placeholder(for swatch: PassagePalette.Swatch) -> UIImage {
        if let hit = placeholderCache[swatch] { return hit }
        let image = render(cover: nil, swatch: swatch)
        placeholderCache[swatch] = image
        return image
    }

    /// 표지 다운로드 후 합성 이미지. 캐시. URL이 없거나 실패하면 표지색 폴백.
    func load(id: UUID, coverURL: String?, swatch: PassagePalette.Swatch) async -> UIImage {
        if let hit = cache[id] { return hit }
        var cover: UIImage?
        if let coverURL, let url = URL(string: coverURL),
           let (data, _) = try? await URLSession.shared.data(from: url) {
            cover = UIImage(data: data)
        }
        let composed = render(cover: cover, swatch: swatch)
        cache[id] = composed
        return composed
    }

    // MARK: 드로잉

    private func render(cover: UIImage?, swatch: PassagePalette.Swatch) -> UIImage {
        let inset = Self.inset
        let cardRect = CGRect(origin: CGPoint(x: inset, y: inset),
                              size: CGSize(width: Self.markerSize.width - inset * 2,
                                           height: Self.markerSize.height - inset * 2))
        let renderer = UIGraphicsImageRenderer(size: Self.markerSize)
        return renderer.image { ctx in
            let cg = ctx.cgContext
            let card = UIBezierPath(roundedRect: cardRect, cornerRadius: Self.corner)

            // 그림자 깔린 흰 카드 바탕
            cg.saveGState()
            cg.setShadow(offset: CGSize(width: 0, height: 1), blur: 3,
                         color: UIColor.black.withAlphaComponent(0.28).cgColor)
            UIColor.white.setFill()
            card.fill()
            cg.restoreGState()

            // 표지 이미지(aspect fill) 또는 표지색 채움
            cg.saveGState()
            card.addClip()
            if let cover {
                cover.draw(in: aspectFillRect(imageSize: cover.size, in: cardRect))
            } else {
                UIColor(swatch.base).setFill()   // 가로 갤러리 카드와 같은 색(swatch.base)으로 통일
                cg.fill(cardRect)
            }
            cg.restoreGState()

            // 얇은 흰 테두리
            UIColor.white.setStroke()
            card.lineWidth = 2
            card.stroke()
        }
    }

    private func aspectFillRect(imageSize: CGSize, in rect: CGRect) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return rect }
        let scale = max(rect.width / imageSize.width, rect.height / imageSize.height)
        let w = imageSize.width * scale
        let h = imageSize.height * scale
        return CGRect(x: rect.midX - w / 2, y: rect.midY - h / 2, width: w, height: h)
    }
}
