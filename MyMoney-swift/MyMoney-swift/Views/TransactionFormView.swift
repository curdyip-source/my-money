//
//  TransactionFormView.swift
//  MyMoney-swift
//
//  Форма добавления и редактирования операции (приход / расход / перевод).
//

import SwiftUI
import SwiftData

struct TransactionFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Account.createdAt) private var accounts: [Account]
    @Query(sort: \TransactionCategory.name) private var categories: [TransactionCategory]
    @Query(sort: \Debt.date, order: .reverse) private var debts: [Debt]
    @Query private var allTransactions: [Transaction]

    /// Счёт, выбранный в прошлый раз, — подставляется по умолчанию у новой операции.
    @AppStorage("lastAccountUID") private var lastAccountUID: String = ""

    /// Редактируемая операция; nil — создаём новую.
    var transaction: Transaction?

    @State private var type: TransactionType = .expense
    @State private var amountText: String = ""
    @State private var transferAmountText: String = ""
    @State private var details: String = ""
    @State private var hashtagsText: String = ""
    @State private var date: Date = Date()
    @State private var account: Account?
    @State private var destinationAccount: Account?
    @State private var category: TransactionCategory?
    @State private var selectedDebt: Debt?

    private var isEditing: Bool { transaction != nil }

    /// Это «тело долга» (выдача/получение) — его долговую привязку здесь не меняем.
    private var isPrincipal: Bool { transaction?.isDebtPrincipal ?? false }

    /// Долги, которые можно гасить операцией текущего типа:
    /// приход гасит «мне должны», расход — «я должен». Перевод долги не гасит.
    private var repayableDebts: [Debt] {
        guard type != .transfer, !isPrincipal else { return [] }
        let wantOwedToMe = (type == .income)
        var list = debts.filter { $0.isOwedToMe == wantOwedToMe && !$0.isSettled }
        // Если редактируем операцию с уже погашенным/другим долгом — добавим его в список.
        if let s = selectedDebt, !list.contains(where: { $0.uid == s.uid }) {
            list.insert(s, at: 0)
        }
        return list
    }

    /// Для перевода между счетами в разных валютах нужна вторая сумма.
    private var needsTransferAmount: Bool {
        type == .transfer
            && account != nil && destinationAccount != nil
            && account?.currencyCode != destinationAccount?.currencyCode
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Тип", selection: $type) {
                        ForEach(TransactionType.allCases) { t in
                            Text(t.title).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section(type == .transfer ? "Со счёта" : "Счёт") {
                    Picker(type == .transfer ? "Со счёта" : "Счёт", selection: $account) {
                        Text("Не выбран").tag(Account?.none)
                        ForEach(accounts) { acc in
                            Text("\(acc.name) (\(acc.currencyCode))").tag(Account?.some(acc))
                        }
                    }
                    if type == .transfer {
                        Picker("На счёт", selection: $destinationAccount) {
                            Text("Не выбран").tag(Account?.none)
                            ForEach(accounts) { acc in
                                Text("\(acc.name) (\(acc.currencyCode))").tag(Account?.some(acc))
                            }
                        }
                    } else if !repayableDebts.isEmpty {
                        // Погашение долга — здесь же, в одном селекте со счётом.
                        Picker("Гасит долг", selection: $selectedDebt) {
                            Text("Нет").tag(Debt?.none)
                            ForEach(repayableDebts) { debt in
                                Text("\(debt.person.isEmpty ? "Без имени" : debt.person) — осталось \(Currency.string(debt.remaining, code: debt.currencyCode))")
                                    .tag(Debt?.some(debt))
                            }
                        }
                    }
                }

                Section("Сумма") {
                    HStack {
                        TextField("0", text: $amountText)
                            .keyboardType(.decimalPad)
                        Text(account?.currencyCode ?? "")
                            .foregroundStyle(.secondary)
                    }
                    if needsTransferAmount {
                        HStack {
                            Text("Зачислить")
                            TextField("0", text: $transferAmountText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                            Text(destinationAccount?.currencyCode ?? "")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if type != .transfer {
                    Section("Категория") {
                        Picker("Категория", selection: $category) {
                            Text("Без категории").tag(TransactionCategory?.none)
                            ForEach(categories) { cat in
                                Label(cat.name, systemImage: cat.systemImage)
                                    .tag(TransactionCategory?.some(cat))
                            }
                        }
                    }
                }

                Section("Детали") {
                    TextField("Описание", text: $details, axis: .vertical)
                        .lineLimit(1...3)
                    VStack(alignment: .leading, spacing: 6) {
                        TextField("#хештеги через пробел", text: $hashtagsText)
                            .autocapitalization(.none)
                        // Ранее использованные хештеги — тап добавляет/убирает тег.
                        if !usedHashtags.isEmpty {
                            WrapLayout(spacing: 6) {
                                ForEach(usedHashtags, id: \.self) { tag in
                                    hashtagChip(tag)
                                }
                            }
                        }
                    }
                    DatePicker("Дата и время", selection: $date)
                }
            }
            .navigationTitle(isEditing ? "Изменить операцию" : "Новая операция")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { save() }
                        .disabled(!isValid)
                }
            }
            .onAppear(perform: load)
            .onChange(of: type) { _, _ in
                // Долг другого направления неактуален при смене типа операции.
                selectedDebt = nil
            }
            .dismissKeyboardButton()
        }
    }

    // MARK: - Хештеги

    /// Ранее использованные хештеги, по алфавиту. Если выбрана категория —
    /// показываем только теги, встречавшиеся с этой категорией (заправка/ремонт
    /// для «Транспорт» и т.п.); без категории — все использованные теги.
    private var usedHashtags: [String] {
        var set = Set<String>()
        for tx in allTransactions {
            if let cat = category, tx.category?.uid != cat.uid { continue }
            set.formUnion(tx.hashtags)
        }
        return set.sorted()
    }

    /// Чип хештега: подсвечен, если уже добавлен в поле.
    private func hashtagChip(_ tag: String) -> some View {
        let active = HashtagParser.parse(hashtagsText).contains(tag)
        return Button {
            toggleHashtag(tag)
        } label: {
            Text("#\(tag)")
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(active ? Color.accentColor.opacity(0.2) : Color(.secondarySystemFill),
                            in: Capsule())
                .foregroundStyle(active ? Color.accentColor : Color.secondary)
        }
        .buttonStyle(.plain)
    }

    /// Добавляет тег в поле ввода, а при повторном тапе — убирает.
    private func toggleHashtag(_ tag: String) {
        var tags = HashtagParser.parse(hashtagsText)
        if let idx = tags.firstIndex(of: tag) {
            tags.remove(at: idx)
        } else {
            tags.append(tag)
        }
        hashtagsText = HashtagParser.display(tags)
    }

    // MARK: - Валидация

    private var isValid: Bool {
        guard parseNumber(amountText) > 0 else { return false }
        guard account != nil else { return false }
        if type == .transfer {
            guard let dest = destinationAccount, dest.uid != account?.uid else { return false }
            if needsTransferAmount, parseNumber(transferAmountText) <= 0 { return false }
        }
        return true
    }

    // MARK: - Загрузка / сохранение

    private func load() {
        if let tx = transaction {
            type = tx.type
            amountText = formatNumber(tx.amount)
            if let ta = tx.transferAmount { transferAmountText = formatNumber(ta) }
            details = tx.details
            hashtagsText = HashtagParser.display(tx.hashtags)
            date = tx.date
            account = tx.account
            destinationAccount = tx.destinationAccount
            category = tx.category
            selectedDebt = tx.isDebtPrincipal ? nil : tx.debt
        } else if account == nil {
            // Подставляем счёт из прошлой операции, иначе — первый в списке.
            account = accounts.first(where: { $0.uid.uuidString == lastAccountUID }) ?? accounts.first
        }
    }

    private func save() {
        let amount = parseNumber(amountText)
        let tags = HashtagParser.parse(hashtagsText)
        let transferAmount: Double? = needsTransferAmount ? parseNumber(transferAmountText) : nil
        let cat = type == .transfer ? nil : category
        let dest = type == .transfer ? destinationAccount : nil
        // Долг гасит приход («мне должны») или расход («я должен»), но не перевод.
        // Остаток долга пересчитывается автоматически из связанных операций.
        // У «тела долга» долговую привязку сохраняем как есть.
        let linkedDebt = isPrincipal ? transaction?.debt : (type == .transfer ? nil : selectedDebt)

        if let tx = transaction {
            tx.type = type
            tx.amount = amount
            tx.transferAmount = transferAmount
            tx.details = details
            tx.hashtags = tags
            tx.date = date
            tx.account = account
            tx.destinationAccount = dest
            tx.category = cat
            tx.debt = linkedDebt
        } else {
            let new = Transaction(type: type, amount: amount, details: details,
                                  hashtags: tags, date: date, category: cat,
                                  account: account, destinationAccount: dest,
                                  transferAmount: transferAmount)
            new.debt = linkedDebt
            context.insert(new)
        }
        // Запоминаем счёт как значение по умолчанию для следующей операции.
        if let acc = account {
            lastAccountUID = acc.uid.uuidString
        }
        try? context.save()
        dismiss()
    }
}
