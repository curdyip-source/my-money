//
//  Debt.swift
//  MyMoney-swift
//
//  Модель долга: деньги, которые мне должны или которые должен я.
//  Это отдельный реестр и он не влияет на баланс счетов.
//

import Foundation
import SwiftData

@Model
final class Debt {
    var uid: UUID = UUID()
    /// Имя человека (кому дал в долг / у кого взял).
    var person: String = ""
    /// Сумма долга. Всегда положительная.
    var amount: Double = 0
    /// Валюта долга (ISO 4217).
    var currencyCode: String = "RUB"
    /// true — мне должны (я дал в долг); false — я должен (я взял в долг).
    var isOwedToMe: Bool = true
    /// Дата возникновения долга.
    var date: Date = Date()
    /// Срок возврата (необязательно).
    var dueDate: Date?
    /// Заметка.
    var note: String = ""
    var createdAt: Date = Date()

    /// Операции-погашения, привязанные к этому долгу.
    /// «Погашено» вычисляется из них, поэтому любое создание/изменение/удаление
    /// операции автоматически отражается на остатке долга.
    @Relationship(deleteRule: .nullify, inverse: \Transaction.debt)
    var repayments: [Transaction] = []

    init(person: String,
         amount: Double,
         currencyCode: String,
         isOwedToMe: Bool,
         date: Date = Date(),
         dueDate: Date? = nil,
         note: String = "") {
        self.uid = UUID()
        self.person = person
        self.amount = amount
        self.currencyCode = currencyCode
        self.isOwedToMe = isOwedToMe
        self.date = date
        self.dueDate = dueDate
        self.note = note
        self.createdAt = Date()
    }

    /// Сколько уже погашено — сумма операций-погашений (тело долга не учитывается).
    var repaidAmount: Double {
        repayments.filter { !$0.isDebtPrincipal }.reduce(0) { $0 + $1.amount }
    }

    /// Остаток долга к возврату.
    var remaining: Double { max(0, amount - repaidAmount) }

    /// Доля погашения (0…1).
    var progress: Double { amount > 0 ? min(1, repaidAmount / amount) : 1 }

    /// Долг полностью погашен.
    var isSettled: Bool { remaining <= 0.0001 }
}
