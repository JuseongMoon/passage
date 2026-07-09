//
//  CoverColorFiller.swift
//  passage
//
//  표지 이미지의 대표색을 뽑아 Book.coverColorHex를 채운다(백그라운드).
//  서재 카드색 소스. 뷰 수명과 무관하게 완료되도록 @MainActor 객체가 소유한다(모델 컨텍스트 보유).
//  다운로드·CoreImage 계산은 off-main(nonisolated)에서 하고, 모델 쓰기만 MainActor로 돌아온다. (→ PageCountFiller 패턴)
//

import Foundation
import SwiftData
import Observation
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

@MainActor
@Observable
final class CoverColorFiller {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// 표지 URL은 있는데 색이 비어 있는 책들을 모두 채운다(서재 진입 시 호출 — 멱등).
    func backfillMissing() {
        let descriptor = FetchDescriptor<Book>(
            predicate: #Predicate { $0.coverRemoteURL != nil && $0.coverColorHex == nil }
        )
        guard let books = try? modelContext.fetch(descriptor) else { return }
        for book in books {
            fill(bookID: book.id, coverURL: book.coverRemoteURL)
        }
    }

    /// 한 책의 표지 대표색을 뽑아 저장. 실패/없음이면 조용히 무시(다음 진입에 재시도).
    func fill(bookID: UUID, coverURL: String?) {
        guard let coverURL, !coverURL.isEmpty else { return }
        Task {
            guard let hex = await Self.extractHex(coverURL) else { return }
            let descriptor = FetchDescriptor<Book>(predicate: #Predicate { $0.id == bookID })
            guard let book = try? modelContext.fetch(descriptor).first,
                  book.coverColorHex == nil        // 그새 채워졌으면 덮지 않음
            else { return }
            book.coverColorHex = hex
            try? modelContext.save()
        }
    }

    /// 표지를 내려받아 평균색을 "RRGGBB"로 반환. off-main 순수 계산(actor 격리 없음).
    nonisolated static func extractHex(_ urlString: String) async -> String? {
        guard let url = URL(string: urlString),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let image = UIImage(data: data),
              let cgImage = image.cgImage else { return nil }

        let ciImage = CIImage(cgImage: cgImage)
        let filter = CIFilter.areaAverage()
        filter.inputImage = ciImage
        filter.extent = ciImage.extent
        guard let output = filter.outputImage else { return nil }

        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: NSNull()])
        context.render(
            output,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: nil
        )
        // 완전 투명/이상값 방어: 알파가 0이면 무의미.
        guard bitmap[3] > 0 else { return nil }
        return String(format: "%02X%02X%02X", bitmap[0], bitmap[1], bitmap[2])
    }
}
