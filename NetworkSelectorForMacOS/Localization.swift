//
//  Localization.swift
//  NetworkSelectorForMacOS
//  本地化
//
//  Created by 司晓龙 on 2026/5/13.
//

import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english
    case simplifiedChinese

    var id: String {
        rawValue
    }

    var locale: Locale {
        switch self {
        case .system:
            return .current
        case .english:
            return Locale(identifier: "en")
        case .simplifiedChinese:
            return Locale(identifier: "zh-Hans")
        }
    }
}

func appText(_ key: String, languageSetting: String) -> String {
    let locale = AppLanguage(rawValue: languageSetting)?.locale ?? .current
    return String(localized: String.LocalizationValue(key), locale: locale)
}

func appText(_ key: String, languageSetting: String, _ arguments: CVarArg...) -> String {
    String(format: appText(key, languageSetting: languageSetting), arguments: arguments)
}
