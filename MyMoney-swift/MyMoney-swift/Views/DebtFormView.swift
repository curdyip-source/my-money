//
//  DebtFormView.swift
//  MyMoney-swift
//
//  Форма добавления и редактирования долга.
//

import SwiftUI
import SwiftData

struct DebtFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    /// Редактируемый долг; nil — создаём новый.
    var debt: Debt?

    @Query(sort: \Account.createdAt) private var accounts: [Account]

    @State private var person: String = ""
    @State private var amountText: String = ""
    @State private var currencyCode: String = "RUB"
    @State private var isOwedToMe: Bool = true
    @State private var date: Date = Date()
    @State private var hasDueDate: Bool = false
    @State private var dueDate: Date = Date()
    @State private var note: String = ""
    @State private var account: Account?

    private var isEditing: Bool { debt != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Тип", selection: $isOwedToMe) {
                        Text("Мне должны").tag(true)
                        Text("Я должен").tag(false)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Кто") {
                    TextField(isOwedToMe ? "Кто мне должен" : "Кому я должен", text: $person)
                }

                Section("Сумма") {
                    HStack {
                        TextField("0", text: $amountText)
                            .keyboardType(.decimalPad)
                        Picker("", selection: $currencyCode) {
                            ForEach(Currency.common, id: \.self) { Text($0).tag($0) }
                        }
                        .labelsHidden()
                    }
                }

                Section(isOwedToMe ? "Списать со счёта" : "Зачислить на счёт") {
                    Picker("Счёт", selection: $account) {
                        Text("Не выбран").tag(Account?.none)
                        ForEach(accounts) { acc in
                            Text("\(acc.name) (\(acc.currencyCode))").tag(Account?.some(acc))
                        }
                    }
                    Text(isOwedToMe
                         ? "Выдача долга спишется со счёта расходной операцией."
                         : "Полученный долг зачислится на счёт приходной операцией.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Детали") {
                    DatePicker("Дата", selection: $date, displayedComponents: [.date])
                    Toggle("Срок возврата", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker("Вернуть до", selection: $dueDate, displayedComponents: [.date])
                    }
                    TextField("Заметка", text: $note, axis: .vertical)
                        .lineLimit(1...3)
                }
            }
            .navigationTitle(isEditing ? "Изменить долг" : "Новый долг")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { save() }
                        .disabled(parseNumber(amountText) <= 0 || account == nil)
                }
            }
            .onAppear(perform: load)
            .dismissKeyboardButton()
        }
    }

    private func load() {
        if account == nil {
            account = accounts.first { $0.currencyCode == currencyCode } ?? accounts.first
        }
        guard let debt else { return }
        person = debt.person
        amountText = formatNumber(debt.amount)
        currencyCode = debt.currencyCode
        isOwedToMe = debt.isOwedToMe
        date = debt.date
        if let due = debt.dueDate {
            hasDueDate = true
            dueDate = due
        }
        note = debt.note
        // Счёт берём из «тела долга», если оно есть.
        if let principal = debt.repayments.first(where: { $0.isDebtPrincipal }) {
            account = principal.account
        }
    }

    private func save() {
        let amount = parseNumber(amountText)
        let trimmedPerson = person.trimmingCharacters(in: .whitespaces)
        let due: Date? = hasDueDate ? dueDate : nil
        // Тело долга — операция: выдал в долг → расход, взял в долг → приход.
        let principalType: TransactionType = isOwedToMe ? .expense : .income
        let principalDetails = isOwedToMe ? "Выдан долг: \(trimmedPerson)" : "Получен долг: \(trimmedPerson)"

        let target: Debt
        if let debt {
            debt.person = trimmedPerson
            debt.amount = amount
            debt.currencyCode = currencyCode
            debt.isOwedToMe = isOwedToMe
            debt.date = date
            debt.dueDate = due
            debt.note = note
            target = debt
        } else {
            let new = Debt(person: trimmedPerson, amount: amount, currencyCode: currencyCode,
                           isOwedToMe: isOwedToMe, date: date, dueDate: due, note: note)
            context.insert(new)
            target = new
        }

        // Создаём или синхронизируем «тело долга» (операцию по счёту).
        if let principal = target.repayments.first(where: { $0.isDebtPrincipal }) {
            principal.amount = amount
            principal.type = principalType
            principal.account = account
            principal.date = date
            principal.details = principalDetails
        } else {
            let principal = Transaction(type: principalType, amount: amount,
                                        details: principalDetails, date: date, account: account)
            principal.isDebtPrincipal = true
            principal.debt = target
            context.insert(principal)
        }

        try? context.save()
        dismiss()
    }
}
