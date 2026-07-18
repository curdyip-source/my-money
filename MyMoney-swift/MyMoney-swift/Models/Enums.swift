//
//  Enums.swift
//  MyMoney-swift
//
//  Базовые перечисления предметной области: типы счетов и типы операций.
//

import Foundation

/// Тип денежного счёта.
enum AccountType: String, Codable, CaseIterable, Identifiable {
    case bank        // банковский счёт
    case creditCard  // кредитная карта
    case cash        // наличные

    var id: String { rawValue }

    /// Локализованное название для интерфейса.
    var title: String {
        switch self {
        case .bank: return "Банковский счёт"
        case .creditCard: return "Кредитная карта"
        case .cash: return "Наличные"
        }
    }

    /// Иконка SF Symbols.
    var systemImage: String {
        switch self {
        case .bank: return "building.columns"
        case .creditCard: return "creditcard"
        case .cash: return "banknote"
        }
    }
}

/// Тип операции.
enum TransactionType: String, Codable, CaseIterable, Identifiable {
    case income    // приход
    case expense   // расход
    case transfer  // перевод между счетами

    var id: String { rawValue }

    var title: String {
        switch self {
        case .income: return "Приход"
        case .expense: return "Расход"
        case .transfer: return "Перевод"
        }
    }

    var systemImage: String {
        switch self {
        case .income: return "arrow.down.circle.fill"
        case .expense: return "arrow.up.circle.fill"
        case .transfer: return "arrow.left.arrow.right.circle.fill"
        }
    }
}
