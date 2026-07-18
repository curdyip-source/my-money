//
//  AccountFormView.swift
//  MyMoney-swift
//
//  Форма создания и редактирования счёта.
//

import SwiftUI
import SwiftData

struct AccountFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    /// Редактируемый счёт; nil — создаём новый.
    var account: Account?

    @State private var name: String = ""
    @State private var type: AccountType = .cash
    @State private var currencyCode: String = "RUB"
    @State private var initialBalanceText: String = ""
    @State private var creditLimitText: String = ""

    private var isEditing: Bool { account != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Основное") {
                    TextField("Название счёта", text: $name)

                    Picker("Тип счёта", selection: $type) {
                        ForEach(AccountType.allCases) { t in
                            Label(t.title, systemImage: t.systemImage).tag(t)
                        }
                    }

                    Picker("Валюта", selection: $currencyCode) {
                        ForEach(Currency.common, id: \.self) { code in
                            Text(code).tag(code)
                        }
                    }
                }

                Section("Баланс") {
                    HStack {
                        Text("Начальный остаток")
                        Spacer()
                        TextField("0", text: $initialBalanceText)
                            .keyboardType(.numbersAndPunctuation)
                            .multilineTextAlignment(.trailing)
                    }
                }

                if type == .creditCard {
                    Section("Кредитная карта") {
                        HStack {
                            Text("Кредитный лимит")
                            Spacer()
                            TextField("0", text: $creditLimitText)
                                .keyboardType(.numbersAndPunctuation)
                                .multilineTextAlignment(.trailing)
                        }
                        Text("Баланс может быть отрицательным в пределах лимита.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(isEditing ? "Изменить счёт" : "Новый счёт")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear(perform: loadIfEditing)
            .dismissKeyboardButton()
        }
    }

    private func loadIfEditing() {
        guard let account else { return }
        name = account.name
        type = account.type
        currencyCode = account.currencyCode
        initialBalanceText = formatNumber(account.initialBalance)
        if let limit = account.creditLimit {
            creditLimitText = formatNumber(limit)
        }
    }

    private func save() {
        let initial = parseNumber(initialBalanceText)
        let limit: Double? = type == .creditCard ? parseNumber(creditLimitText) : nil
        let trimmedName = name.trimmingCharacters(in: .whitespaces)

        if let account {
            account.name = trimmedName
            account.type = type
            account.currencyCode = currencyCode
            account.initialBalance = initial
            account.creditLimit = limit
        } else {
            let new = Account(name: trimmedName, type: type, currencyCode: currencyCode,
                              initialBalance: initial, creditLimit: limit)
            context.insert(new)
        }
        try? context.save()
        dismiss()
    }
}

// MARK: - Разбор и форматирование чисел (поддержка запятой как разделителя)

func parseNumber(_ text: String) -> Double {
    let normalized = text
        .replacingOccurrences(of: " ", with: "")
        .replacingOccurrences(of: ",", with: ".")
    return Double(normalized) ?? 0
}

func formatNumber(_ value: Double) -> String {
    if value == value.rounded() {
        return String(format: "%.0f", value)
    }
    return String(value)
}
