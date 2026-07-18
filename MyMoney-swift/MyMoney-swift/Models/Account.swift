//
//  Account.swift
//  MyMoney-swift
//
//  Модель денежного счёта (кошелька).
//

import Foundation
import SwiftData

@Model
final class Account {
    /// Уникальный идентификатор (для надёжного сравнения в расчётах баланса).
    var uid: UUID = UUID()
    /// Название счёта, задаётся пользователем.
    var name: String = ""
    /// Тип счёта, хранится строкой (raw value перечисления).
    var typeRaw: String = AccountType.cash.rawValue
    /// Код валюты счёта (ISO 4217): USD, EUR, RUB и т.д.
    var currencyCode: String = "RUB"
    /// Начальный (стартовый) остаток на счёте.
    var initialBalance: Double = 0
    /// Кредитный лимит — только для кредитных карт (баланс может уходить в минус).
    var creditLimit: Double?
    /// Дата создания счёта.
    var createdAt: Date = Date()

    init(name: String,
         type: AccountType,
         currencyCode: String,
         initialBalance: Double = 0,
         creditLimit: Double? = nil,
         createdAt: Date = Date()) {
        self.uid = UUID()
        self.name = name
        self.typeRaw = type.rawValue
        self.currencyCode = currencyCode
        self.initialBalance = initialBalance
        self.creditLimit = creditLimit
        self.createdAt = createdAt
    }

    /// Тип счёта как перечисление.
    var type: AccountType {
        get { AccountType(rawValue: typeRaw) ?? .cash }
        set { typeRaw = newValue.rawValue }
    }
}
