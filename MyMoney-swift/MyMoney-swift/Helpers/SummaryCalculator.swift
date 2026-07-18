//
//  SummaryCalculator.swift
//  MyMoney-swift
//
//  Подсчёт сводки за период: суммы по категориям и хештегам.
//  Суммы приводятся к базовой валюте по заданным курсам.
//

import Foundation

enum SummaryCalculator {

    /// Одна доля сводки (категория или хештег).
    struct Slice: Identifiable {
        let id = UUID()
        let name: String
        let amount: Double
    }

    /// Категория с суммой и вложенной разбивкой по хештегам.
    struct CategoryGroup: Identifiable {
        let id = UUID()
        let name: String
        let amount: Double
        /// Разбивка по хештегам внутри категории (включая «Без хештега»).
        let tags: [Slice]
    }

    /// Метка для операций без хештегов во вложенной разбивке.
    static let noHashtagLabel = "Без хештега"

    /// Перевод суммы из валюты операции в базовую валюту.
    /// Если курс неизвестен — считаем 1:1 (для одновалютного учёта это точно).
    private static func toBase(_ amount: Double, code: String,
                              baseCurrency: String, rates: [String: Double]) -> Double {
        if code == baseCurrency { return amount }
        if let rate = rates[code], rate > 0 { return amount * rate }
        return amount
    }

    /// Суммы по категориям за период (операции уже отфильтрованы по дате и типу).
    static func byCategory(_ transactions: [Transaction],
                           baseCurrency: String, rates: [String: Double]) -> [Slice] {
        var totals: [String: Double] = [:]
        for tx in transactions {
            let name = tx.category?.name ?? "Без категории"
            let value = toBase(tx.amount, code: tx.account?.currencyCode ?? baseCurrency,
                               baseCurrency: baseCurrency, rates: rates)
            totals[name, default: 0] += value
        }
        return totals
            .map { Slice(name: $0.key, amount: $0.value) }
            .sorted { $0.amount > $1.amount }
    }

    /// Суммы по категориям с вложенной разбивкой по хештегам.
    /// Внутри категории сумма операции прибавляется к каждому её хештегу,
    /// а операции без хештегов попадают в «Без хештега».
    static func byCategoryDetailed(_ transactions: [Transaction],
                                   baseCurrency: String, rates: [String: Double]) -> [CategoryGroup] {
        // Группируем операции по названию категории.
        var byCategory: [String: [Transaction]] = [:]
        for tx in transactions {
            let name = tx.category?.name ?? "Без категории"
            byCategory[name, default: []].append(tx)
        }

        var groups: [CategoryGroup] = []
        for (name, txs) in byCategory {
            var total: Double = 0
            var tagTotals: [String: Double] = [:]
            for tx in txs {
                let value = toBase(tx.amount, code: tx.account?.currencyCode ?? baseCurrency,
                                   baseCurrency: baseCurrency, rates: rates)
                total += value
                if tx.hashtags.isEmpty {
                    tagTotals[noHashtagLabel, default: 0] += value
                } else {
                    for tag in tx.hashtags {
                        tagTotals[tag, default: 0] += value
                    }
                }
            }
            let tags = tagTotals
                .map { Slice(name: $0.key, amount: $0.value) }
                .sorted { $0.amount > $1.amount }
            groups.append(CategoryGroup(name: name, amount: total, tags: tags))
        }
        return groups.sorted { $0.amount > $1.amount }
    }

    /// Суммы по хештегам за период. Сумма операции прибавляется к каждому её хештегу.
    static func byHashtag(_ transactions: [Transaction],
                          baseCurrency: String, rates: [String: Double]) -> [Slice] {
        var totals: [String: Double] = [:]
        for tx in transactions {
            guard !tx.hashtags.isEmpty else { continue }
            let value = toBase(tx.amount, code: tx.account?.currencyCode ?? baseCurrency,
                               baseCurrency: baseCurrency, rates: rates)
            for tag in tx.hashtags {
                totals[tag, default: 0] += value
            }
        }
        return totals
            .map { Slice(name: $0.key, amount: $0.value) }
            .sorted { $0.amount > $1.amount }
    }
}
