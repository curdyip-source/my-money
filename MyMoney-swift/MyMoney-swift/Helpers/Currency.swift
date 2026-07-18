//
//  Currency.swift
//  MyMoney-swift
//
//  Справочник валют и форматирование денежных сумм.
//

import Foundation

enum Currency {
    /// Наиболее ходовые валюты для выбора при создании счёта.
    static let common: [String] = [
        "RUB", "USD", "EUR", "GBP", "CHF", "JPY", "CNY",
        "KZT", "UAH", "BYN", "TRY", "AED", "GEL", "AMD",
    ]

    /// Символ валюты по коду (₽, $, € …) с запасным вариантом — самим кодом.
    static func symbol(for code: String) -> String {
        let locale = Locale(identifier: "en_US")
        if let symbol = locale.localizedString(forCurrencyCode: code),
           symbol != code {
            // localizedString даёт название, а не символ — берём символ через форматтер ниже.
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        return formatter.currencySymbol ?? code
    }

    /// Форматирует сумму как денежную строку в указанной валюте: "1 234,56 ₽".
    static func string(_ amount: Double, code: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount))
            ?? String(format: "%.2f %@", amount, code)
    }
}
