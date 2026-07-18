//
//  CurrencyRate.swift
//  MyMoney-swift
//
//  Курс валюты относительно базовой валюты приложения.
//  rate = стоимость 1 единицы данной валюты в базовой валюте.
//

import Foundation
import SwiftData

@Model
final class CurrencyRate {
    /// Код валюты (ISO 4217).
    @Attribute(.unique) var code: String = ""
    /// Стоимость 1 единицы этой валюты в базовой валюте.
    var rate: Double = 1

    init(code: String, rate: Double) {
        self.code = code
        self.rate = rate
    }
}
