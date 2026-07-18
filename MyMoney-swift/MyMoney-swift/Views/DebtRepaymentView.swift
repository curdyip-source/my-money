//
//  DebtRepaymentView.swift
//  MyMoney-swift
//
//  Погашение долга из вкладки «Долги». Заводит реальную операцию
//  (приход — если мне должны, расход — если должен я) и привязывает её к долгу.
//

import SwiftUI
import SwiftData

struct DebtRepaymentView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let debt: Debt

    @Query(sort: \Account.createdAt) private var accounts: [Account]

    @State private var amountText: String = ""
    @State private var account: Account?
    @State private var date: Date = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Долг", value: debt.person.isEmpty ? "Без имени" : debt.person)
                    LabeledContent("Остаток",
                                   value: Currency.string(debt.remaining, code: debt.currencyCode))
                }

                Section(debt.isOwedToMe ? "Приход на счёт" : "Списать со счёта") {
                    Picker("Счёт", selection: $account) {
                        Text("Не выбран").tag(Account?.none)
                        ForEach(accounts) { acc in
                            Text("\(acc.name) (\(acc.currencyCode))").tag(Account?.some(acc))
                        }
                    }
                    HStack {
                        TextField("0", text: $amountText)
                            .keyboardType(.decimalPad)
                        Text(debt.currencyCode).foregroundStyle(.secondary)
                    }
                    DatePicker("Дата", selection: $date, displayedComponents: [.date])
                }
            }
            .navigationTitle("Погашение долга")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Погасить") { save() }
                        .disabled(parseNumber(amountText) <= 0 || account == nil)
                }
            }
            .onAppear {
                if amountText.isEmpty { amountText = formatNumber(debt.remaining) }
                if account == nil {
                    account = accounts.first { $0.currencyCode == debt.currencyCode } ?? accounts.first
                }
            }
            .dismissKeyboardButton()
        }
    }

    private func save() {
        let amount = parseNumber(amountText)
        let tx = Transaction(
            type: debt.isOwedToMe ? .income : .expense,
            amount: amount,
            details: "Погашение долга: \(debt.person)",
            date: date,
            account: account
        )
        tx.debt = debt
        context.insert(tx)
        try? context.save()
        dismiss()
    }
}
