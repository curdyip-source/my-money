//
//  Transaction.swift
//  MyMoney-swift
//
//  Модель операции: приход, расход или перевод между счетами.
//

import Foundation
import SwiftData

@Model
final class Transaction {
    var uid: UUID = UUID()
    /// Тип операции (raw value перечисления).
    var typeRaw: String = TransactionType.expense.rawValue
    /// Сумма операции в валюте счёта-источника. Всегда положительная.
    var amount: Double = 0
    /// Сумма зачисления на счёт-получатель (для переводов между разными валютами).
    /// Если nil — используется `amount` (та же валюта).
    var transferAmount: Double?
    /// Текстовое описание операции.
    var details: String = ""
    /// Хештеги (без символа #, в нижнем регистре), например ["отпуск", "подарок"].
    var hashtags: [String] = []
    /// Дата и время операции.
    var date: Date = Date()
    var createdAt: Date = Date()

    /// Категория операции (для приходов/расходов).
    var category: TransactionCategory?
    /// Счёт-источник (откуда списываются деньги или куда приходят).
    var account: Account?
    /// Счёт-получатель — только для переводов.
    var destinationAccount: Account?
    /// Долг, к которому привязана операция (тело долга или его погашение).
    var debt: Debt?
    /// true — это «тело долга» (выдача/получение), а не погашение.
    /// Тело не учитывается в сумме погашения долга.
    var isDebtPrincipal: Bool = false

    init(type: TransactionType,
         amount: Double,
         details: String = "",
         hashtags: [String] = [],
         date: Date = Date(),
         category: TransactionCategory? = nil,
         account: Account? = nil,
         destinationAccount: Account? = nil,
         transferAmount: Double? = nil) {
        self.uid = UUID()
        self.typeRaw = type.rawValue
        self.amount = amount
        self.details = details
        self.hashtags = hashtags
        self.date = date
        self.category = category
        self.account = account
        self.destinationAccount = destinationAccount
        self.transferAmount = transferAmount
        self.createdAt = Date()
    }

    var type: TransactionType {
        get { TransactionType(rawValue: typeRaw) ?? .expense }
        set { typeRaw = newValue.rawValue }
    }
}

// MARK: - Хештеги

enum HashtagParser {
    /// Разбирает строку вида "#отпуск подарок #еда" в нормализованный список тегов
    /// без символа #, в нижнем регистре, без дубликатов.
    static func parse(_ raw: String) -> [String] {
        let tokens = raw
            .replacingOccurrences(of: ",", with: " ")
            .split(whereSeparator: { $0 == " " || $0 == "\n" })
        var result: [String] = []
        for token in tokens {
            let tag = token
                .trimmingCharacters(in: CharacterSet(charactersIn: "#"))
                .trimmingCharacters(in: .whitespaces)
                .lowercased()
            if !tag.isEmpty && !result.contains(tag) {
                result.append(tag)
            }
        }
        return result
    }

    /// Превращает список тегов обратно в строку для поля ввода: "#отпуск #подарок".
    static func display(_ tags: [String]) -> String {
        tags.map { "#\($0)" }.joined(separator: " ")
    }
}
