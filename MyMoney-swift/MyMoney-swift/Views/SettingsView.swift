//
//  SettingsView.swift
//  MyMoney-swift
//
//  Настройки: базовая валюта, курсы конвертации, категории, сброс данных.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Account.createdAt) private var accounts: [Account]
    @Query(sort: \Transaction.date) private var transactions: [Transaction]
    @Query(sort: \TransactionCategory.name) private var categories: [TransactionCategory]
    @Query private var rates: [CurrencyRate]

    @AppStorage("baseCurrency") private var baseCurrency: String = "RUB"

    /// Валюты, реально используемые на счетах.
    private var usedCurrencies: [String] {
        Array(Set(accounts.map { $0.currencyCode })).sorted()
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Категории") {
                    NavigationLink {
                        CategoriesView()
                    } label: {
                        Label("Управление категориями (\(categories.count))", systemImage: "tag")
                    }
                }

                Section("Базовая валюта") {
                    Picker("Базовая валюта", selection: $baseCurrency) {
                        ForEach(Currency.common, id: \.self) { code in
                            Text(code).tag(code)
                        }
                    }
                    Text("В неё пересчитывается общий баланс по заданным ниже курсам.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Курсы валют") {
                    Text("Стоимость 1 единицы валюты в базовой валюте (\(baseCurrency)).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    let others = usedCurrencies.filter { $0 != baseCurrency }
                    if others.isEmpty {
                        Text("Все счета в базовой валюте — курсы не нужны.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(others, id: \.self) { code in
                            CurrencyRateRow(code: code, baseCurrency: baseCurrency)
                        }
                    }
                }

                Section("Данные") {
                    LabeledContent("Счетов", value: "\(accounts.count)")
                    LabeledContent("Операций", value: "\(transactions.count)")
                    Text("Все данные хранятся локально на устройстве. Приложение работает офлайн без авторизации.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Настройки")
            .tabBarBottomInset()
            .dismissKeyboardButton()
        }
    }
}

/// Строка ввода курса одной валюты. Курс хранится в модели CurrencyRate.
struct CurrencyRateRow: View {
    let code: String
    let baseCurrency: String

    @Environment(\.modelContext) private var context
    @Query private var rates: [CurrencyRate]
    @State private var text: String = ""

    init(code: String, baseCurrency: String) {
        self.code = code
        self.baseCurrency = baseCurrency
        let predicate = #Predicate<CurrencyRate> { $0.code == code }
        _rates = Query(filter: predicate)
    }

    private var existing: CurrencyRate? { rates.first }

    var body: some View {
        HStack {
            Text("1 \(code) =")
            TextField("0", text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .onChange(of: text) { _, newValue in
                    saveRate(parseNumber(newValue))
                }
            Text(baseCurrency)
                .foregroundStyle(.secondary)
        }
        .onAppear {
            if let rate = existing, text.isEmpty {
                text = formatNumber(rate.rate)
            }
        }
    }

    private func saveRate(_ value: Double) {
        guard value > 0 else { return }
        if let existing {
            existing.rate = value
        } else {
            context.insert(CurrencyRate(code: code, rate: value))
        }
        try? context.save()
    }
}
