//
//  BalanceCalculator.swift
//  MyMoney-swift
//
//  Пересчёт балансов счетов на основе списка операций.
//  Баланс не хранится в БД, а вычисляется, чтобы всегда быть актуальным.
//

import Foundation

enum BalanceCalculator {

    /// Текущий баланс одного счёта: начальный остаток + влияние всех операций.
    static func balance(for account: Account, transactions: [Transaction]) -> Double {
        var total = account.initialBalance
        for tx in transactions {
            switch tx.type {
            case .income:
                if tx.account?.uid == account.uid { total += tx.amount }
            case .expense:
                if tx.account?.uid == account.uid { total -= tx.amount }
            case .transfer:
                if tx.account?.uid == account.uid { total -= tx.amount }
                if tx.destinationAccount?.uid == account.uid {
                    total += (tx.transferAmount ?? tx.amount)
                }
            }
        }
        return total
    }

    /// Сумма балансов по каждой валюте отдельно.
    /// Возвращает словарь [код валюты: сумма].
    static func totalsByCurrency(accounts: [Account], transactions: [Transaction]) -> [String: Double] {
        var totals: [String: Double] = [:]
        for account in accounts {
            let value = balance(for: account, transactions: transactions)
            totals[account.currencyCode, default: 0] += value
        }
        return totals
    }

    /// Конвертированный общий баланс в базовой валюте по заданным курсам.
    /// `rates` — словарь [код валюты: стоимость 1 единицы в базовой валюте].
    /// Базовая валюта имеет курс 1. Если курс для валюты неизвестен — она пропускается,
    /// а её код добавляется в `missing`.
    static func convertedTotal(accounts: [Account],
                               transactions: [Transaction],
                               baseCurrency: String,
                               rates: [String: Double]) -> (total: Double, missing: [String]) {
        let totals = totalsByCurrency(accounts: accounts, transactions: transactions)
        var grand: Double = 0
        var missing: [String] = []
        for (code, sum) in totals {
            if code == baseCurrency {
                grand += sum
            } else if let rate = rates[code], rate > 0 {
                grand += sum * rate
            } else {
                missing.append(code)
            }
        }
        return (grand, missing.sorted())
    }
}
