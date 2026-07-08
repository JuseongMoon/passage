//
//  AppearanceMode.swift
//  passage
//
//  화면 모드(라이트/다크) 선택. 기본은 시스템(폰 설정)을 따른다.
//  설정에서 고르면 앱 전역에 preferredColorScheme으로 적용된다.
//

import SwiftUI

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: "시스템"
        case .light:  "라이트"
        case .dark:   "다크"
        }
    }

    /// 앱에 적용할 색 구성. 시스템이면 nil(= 폰 설정을 따름).
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light:  .light
        case .dark:   .dark
        }
    }
}

/// @AppStorage 키(설정과 루트가 공유).
enum AppStorageKey {
    static let appearanceMode = "appearanceMode"
}
