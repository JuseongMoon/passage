//
//  PassagePalette.swift
//  passage
//
//  서재 "보딩패스" 재구성의 색 토큰. (→ Docs/UI_GUIDE.md, DECISIONS 재구성 결정)
//  목업의 따뜻한 팔레트를 중앙화한다 — 매직 넘버 대신 이 토큰만 사용한다.
//  뉴트럴 표면은 라이트/다크 각각 정의하고, 책별 컬러 스와치는 book.id로 결정적 배정한다.
//

import SwiftUI
import UIKit

enum PassagePalette {

    // MARK: 뉴트럴 표면 (라이트/다크 적응)

    /// 앱 배경(따뜻한 오프화이트).
    static let appBg = Color(light: 0xFAF8F8, dark: 0x1A1917)
    /// 펼친 패스 바디 카드 배경.
    static let cardBody = Color(light: 0xEDEAE5, dark: 0x262421)
    /// 기본 잉크(거의 검정).
    static let ink = Color(light: 0x26241F, dark: 0xF2EFEA)
    /// 보조 텍스트.
    static let inkMuted = Color(light: 0x98917F, dark: 0x9A9384)
    /// 흐린 텍스트(자동 채움 안내 등).
    static let inkFaint = Color(light: 0xB3AD9E, dark: 0x736D60)
    /// 입력/구분선 헤어라인.
    static let hairline = Color(light: 0xE2DED5, dark: 0x3A372F)
    /// 티켓 파선 색.
    static let ticketDash = Color(light: 0xCECECE, dark: 0x4A4740)
    /// 진행률 바코드의 꺼진 틱.
    static let progressOff = Color(light: 0xD9D5CC, dark: 0x413D34)
    /// 입력 필드 배경(라이트=흰색).
    static let field = Color(light: 0xFFFFFF, dark: 0x2E2B27)

    // MARK: 액센트

    /// 따뜻한 오렌지 액센트(위치 핀·원형 타이머 틱 등).
    static let warmAccent = Color(light: 0xEB7127, dark: 0xEB7127)
    /// 책 색 위에 얹는 CTA 알약(독서 세션) — 책색·라이트/다크와 무관하게 어두운 알약 + 흰 텍스트로 통일.
    static let ctaInk = Color(hex: 0x26241F)
    /// 파괴적 동작(삭제).
    static let danger = Color(light: 0xC73B2D, dark: 0xE0574A)

    // MARK: 책별 컬러 스와치

    /// 패스 헤더 배경/커버에 쓰이는 한 책의 색 세트.
    struct Swatch: Hashable, Sendable {
        /// 헤더 스트립 배경.
        let base: Color
        /// base 위 텍스트/아이콘 색.
        let ink: Color
        /// 표지 자리표시(면) 색.
        let cover: Color
        /// base 위 흐린 텍스트(날짜 등).
        var dim: Color { ink.opacity(0.7) }
    }

    /// 목업에서 온 따뜻한 8색. 밝은 톤(#c8b48a)만 잉크가 어둡다.
    static let swatches: [Swatch] = [
        Swatch(base: Color(hex: 0x6E5A48), ink: .white,             cover: Color(hex: 0xB0813F)),
        Swatch(base: Color(hex: 0xA3543C), ink: .white,             cover: Color(hex: 0x8A6D4E)),
        Swatch(base: Color(hex: 0x4D6B5C), ink: .white,             cover: Color(hex: 0x7A5560)),
        Swatch(base: Color(hex: 0xE05A2A), ink: .white,             cover: Color(hex: 0x3F584C)),
        Swatch(base: Color(hex: 0x3F584C), ink: .white,             cover: Color(hex: 0x8A6D4E)),
        Swatch(base: Color(hex: 0xC8B48A), ink: Color(hex: 0x26241F), cover: Color(hex: 0x5A6A7A)),
        Swatch(base: Color(hex: 0x5A6A7A), ink: .white,             cover: Color(hex: 0x7A5560)),
        Swatch(base: Color(hex: 0x8F8770), ink: .white,             cover: Color(hex: 0xB0813F)),
    ]

    /// 책 id로 스와치를 **결정적으로** 고른다.
    /// 주의: Swift의 `hashValue`는 프로세스마다 랜덤화되므로 쓰지 않는다 —
    /// UUID 바이트에 FNV-1a를 돌려 실행 간 안정적인 인덱스를 얻는다.
    static func swatch(for book: Book) -> Swatch {
        swatches[swatchIndex(for: book.id)]
    }

    /// FNV-1a(64-bit) over the UUID's 16 bytes → 스와치 인덱스. (테스트에서 안정성 검증)
    static func swatchIndex(for id: UUID) -> Int {
        var hash: UInt64 = 1469598103934665603          // FNV offset basis
        withUnsafeBytes(of: id.uuid) { raw in
            for byte in raw {
                hash ^= UInt64(byte)
                hash = hash &* 1099511628211            // FNV prime
            }
        }
        return Int(hash % UInt64(swatches.count))
    }

    // MARK: 표지 대표색 → 서재 카드 Swatch (은은한 톤 · 라이브러리 전용)

    /// 표지에서 추출한 대표색(0xRRGGBB)으로 서재 카드용 **은은한** Swatch를 만든다.
    /// - base: 채도·명도를 차분한 중간 톤 밴드로 정규화(과채도/과명암 완화, 어두운 잉크 가독 확보).
    /// - ink: 정규화 base의 상대휘도로 어두운 잉크(#26241F) / 아주 어두우면 흰색 자동.
    /// - cover: base를 살짝 어둡게(표지 자리표시용).
    /// 전부 고정 hex Color(라이트/다크 동일) — 동적 프로바이더 미사용(off-main 트랩 없음).
    nonisolated static func coverSwatch(hex: UInt32) -> Swatch {
        var hsb = PassageColorMath.hsb(fromHex: hex)
        hsb.s = min(hsb.s, 0.52)                          // 채도 상한(과채도 완화)
        hsb.b = min(max(hsb.b, 0.60), 0.74)               // 명도 밴드(가독 + 너무 밝지 않게)
        let base = PassageColorMath.hex(fromHSB: hsb)

        let inkHex: UInt32 = PassageColorMath.relativeLuminance(ofHex: base) < 0.16 ? 0xFFFFFF : 0x26241F

        var coverHSB = hsb
        coverHSB.b = max(0.40, hsb.b * 0.80)              // 표지 자리표시는 살짝 어둡게
        let cover = PassageColorMath.hex(fromHSB: coverHSB)

        return Swatch(base: Color(hex: base), ink: Color(hex: inkHex), cover: Color(hex: cover))
    }
}

// MARK: - 색 변환(HSB/휘도) — 은은한 정규화·잉크 판정용 순수 계산

/// RGB↔HSB 변환과 상대휘도. `nonisolated` 순수 값 계산(뷰 격리와 무관, 테스트 대상).
enum PassageColorMath {
    struct HSB: Equatable { var h: Double; var s: Double; var b: Double }   // 각 0…1

    nonisolated static func hsb(fromHex hex: UInt32) -> HSB {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        let mx = max(r, g, b), mn = min(r, g, b), delta = mx - mn
        var h = 0.0
        if delta != 0 {
            if mx == r { h = ((g - b) / delta).truncatingRemainder(dividingBy: 6) }
            else if mx == g { h = (b - r) / delta + 2 }
            else { h = (r - g) / delta + 4 }
            h /= 6
            if h < 0 { h += 1 }
        }
        let s = mx == 0 ? 0 : delta / mx
        return HSB(h: h, s: s, b: mx)
    }

    nonisolated static func hex(fromHSB hsb: HSB) -> UInt32 {
        let h = hsb.h * 6
        let i = floor(h)
        let f = h - i
        let p = hsb.b * (1 - hsb.s)
        let q = hsb.b * (1 - f * hsb.s)
        let t = hsb.b * (1 - (1 - f) * hsb.s)
        let (r, g, b): (Double, Double, Double)
        switch Int(i) % 6 {
        case 0: (r, g, b) = (hsb.b, t, p)
        case 1: (r, g, b) = (q, hsb.b, p)
        case 2: (r, g, b) = (p, hsb.b, t)
        case 3: (r, g, b) = (p, q, hsb.b)
        case 4: (r, g, b) = (t, p, hsb.b)
        default: (r, g, b) = (hsb.b, p, q)
        }
        func byte(_ c: Double) -> UInt32 { UInt32((min(max(c, 0), 1) * 255).rounded()) }
        return (byte(r) << 16) | (byte(g) << 8) | byte(b)
    }

    /// WCAG 상대휘도(0…1). 잉크(어두운/흰) 판정용.
    nonisolated static func relativeLuminance(ofHex hex: UInt32) -> Double {
        func lin(_ c: Double) -> Double { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        let r = lin(Double((hex >> 16) & 0xFF) / 255)
        let g = lin(Double((hex >> 8) & 0xFF) / 255)
        let b = lin(Double(hex & 0xFF) / 255)
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }
}

// MARK: - Color(hex:) 헬퍼

extension Color {
    /// 0xRRGGBB 정수로 색 생성.
    /// `nonisolated` 필수: 아래 `init(light:dark:)`의 dynamicProvider 클로저가
    /// UIKit에 의해 비-메인(SwiftUI AsyncRenderer) 스레드에서 호출될 수 있으므로,
    /// 이 순수 값 계산이 MainActor 격리를 요구하면 런타임 격리 단언이 크래시한다.
    nonisolated init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }

    /// 라이트/다크에서 각각 다른 hex를 쓰는 적응형 색.
    /// `nonisolated` 필수: `UIColor(dynamicProvider:)`는 trait 해석 시점에 임의 스레드
    /// (렌더 서버/AsyncRenderer 포함)에서 클로저를 호출한다. 모듈 기본격리가 MainActor라
    /// 이 클로저가 @MainActor로 추론되면 비-메인 호출 시 dispatch_assert_queue가 크래시한다.
    nonisolated init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(Color(hex: dark))
                : UIColor(Color(hex: light))
        })
    }
}
