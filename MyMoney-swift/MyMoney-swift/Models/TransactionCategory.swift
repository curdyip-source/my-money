//
//  TransactionCategory.swift
//  MyMoney-swift
//
//  Модель категории операций (редактируемый список).
//  Имя `TransactionCategory`, а не `Category`, чтобы не конфликтовать
//  с системным типом `Category` (OpaquePointer из ObjectiveC runtime).
//

import Foundation
import SwiftData

@Model
final class TransactionCategory {
    var uid: UUID = UUID()
    /// Название категории (Еда, Транспорт, Зарплата и т.п.).
    var name: String = ""
    /// Иконка SF Symbols.
    var systemImage: String = "tag"
    var createdAt: Date = Date()

    init(name: String, systemImage: String = "tag", createdAt: Date = Date()) {
        self.uid = UUID()
        self.name = name
        self.systemImage = systemImage
        self.createdAt = createdAt
    }

    /// Категории по умолчанию, создаются при первом запуске.
    static let defaults: [(String, String)] = [
        ("Еда", "fork.knife"),
        ("Транспорт", "car.fill"),
        ("Зарплата", "dollarsign.circle.fill"),
        ("Развлечения", "gamecontroller.fill"),
        ("Жильё", "house.fill"),
        ("Здоровье", "cross.case.fill"),
        ("Покупки", "bag.fill"),
        ("Связь", "wifi"),
        ("Прочее", "ellipsis.circle.fill"),
    ]
}
