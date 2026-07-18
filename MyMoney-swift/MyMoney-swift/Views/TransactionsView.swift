//
//  TransactionsView.swift
//  MyMoney-swift
//
//  Список операций с поиском и фильтрами (категория, хештег, счёт, период).
//

import SwiftUI
import SwiftData

struct TransactionsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query(sort: \Account.createdAt) private var accounts: [Account]
    @Query(sort: \TransactionCategory.name) private var categories: [TransactionCategory]

    @State private var searchText = ""
    @State private var filterAccount: Account?
    @State private var filterCategory: TransactionCategory?
    @State private var filterHashtag: String = ""
    @State private var dateFrom: Date?
    @State private var dateTo: Date?
    @State private var showingFilters = false
    @State private var showingNewTransaction = false
    @State private var editingTransaction: Transaction?
    @State private var transactionToDelete: Transaction?

    var body: some View {
        NavigationStack {
            Group {
                if transactions.isEmpty {
                    ContentUnavailableView(
                        "Нет операций",
                        systemImage: "list.bullet.rectangle",
                        description: Text("Добавьте операцию кнопкой «+»")
                    )
                } else if filtered.isEmpty {
                    ContentUnavailableView.search
                } else {
                    transactionList
                }
            }
            .horizontalScrollPadding()
            .tabBarBottomInset()
            .navigationTitle("Операции")
            .searchable(text: $searchText, prompt: "Поиск по описанию и #хештегам")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingFilters = true
                    } label: {
                        Image(systemName: hasActiveFilters
                              ? "line.3.horizontal.decrease.circle.fill"
                              : "line.3.horizontal.decrease.circle")
                    }
                    .disabled(transactions.isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingNewTransaction = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(accounts.isEmpty)
                }
            }
            .sheet(isPresented: $showingNewTransaction) {
                TransactionFormView()
            }
            .sheet(item: $editingTransaction) { tx in
                TransactionFormView(transaction: tx)
            }
            .sheet(isPresented: $showingFilters) {
                filtersSheet
            }
            .confirmationDialog(
                "Удалить операцию?",
                isPresented: Binding(get: { transactionToDelete != nil },
                                     set: { if !$0 { transactionToDelete = nil } }),
                titleVisibility: .visible,
                presenting: transactionToDelete
            ) { tx in
                Button("Удалить", role: .destructive) {
                    context.delete(tx)
                    try? context.save()
                    transactionToDelete = nil
                }
                Button("Отмена", role: .cancel) { transactionToDelete = nil }
            } message: { _ in
                Text("Операция будет удалена без возможности восстановления.")
            }
            .overlay(alignment: .bottom) {
                if accounts.isEmpty {
                    Text("Сначала создайте счёт на вкладке «Счета».")
                        .font(.caption)
                        .padding(8)
                        .background(.thinMaterial, in: Capsule())
                        .padding(.bottom, 8)
                }
            }
        }
    }

    // MARK: - Список

    private var transactionList: some View {
        List {
            ForEach(filtered) { tx in
                Button {
                    editingTransaction = tx
                } label: {
                    TransactionRow(tx: tx)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button {
                        editingTransaction = tx
                    } label: {
                        Label("Изменить", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        transactionToDelete = tx
                    } label: {
                        Label("Удалить", systemImage: "trash")
                    }
                }
            }
        }
    }

    // MARK: - Фильтрация

    private var hasActiveFilters: Bool {
        filterAccount != nil || filterCategory != nil || !filterHashtag.isEmpty
            || dateFrom != nil || dateTo != nil
    }

    private var filtered: [Transaction] {
        transactions.filter { tx in
            // Поиск по описанию и хештегам.
            if !searchText.isEmpty {
                let needle = searchText.lowercased()
                    .trimmingCharacters(in: CharacterSet(charactersIn: "#"))
                let inDetails = tx.details.lowercased().contains(needle)
                let inTags = tx.hashtags.contains { $0.contains(needle) }
                if !inDetails && !inTags { return false }
            }
            // Счёт (источник или получатель).
            if let acc = filterAccount {
                if tx.account?.uid != acc.uid && tx.destinationAccount?.uid != acc.uid {
                    return false
                }
            }
            // Категория.
            if let cat = filterCategory, tx.category?.uid != cat.uid { return false }
            // Хештег.
            if !filterHashtag.isEmpty, !tx.hashtags.contains(filterHashtag) { return false }
            // Период.
            if let from = dateFrom, tx.date < from { return false }
            if let to = dateTo, tx.date > to { return false }
            return true
        }
    }

    private var allHashtags: [String] {
        var set = Set<String>()
        for tx in transactions { set.formUnion(tx.hashtags) }
        return set.sorted()
    }

    // MARK: - Лист фильтров

    private var filtersSheet: some View {
        NavigationStack {
            Form {
                Section("Счёт") {
                    Picker("Счёт", selection: $filterAccount) {
                        Text("Все").tag(Account?.none)
                        ForEach(accounts) { acc in
                            Text(acc.name).tag(Account?.some(acc))
                        }
                    }
                }
                Section("Категория") {
                    Picker("Категория", selection: $filterCategory) {
                        Text("Все").tag(TransactionCategory?.none)
                        ForEach(categories) { cat in
                            Text(cat.name).tag(TransactionCategory?.some(cat))
                        }
                    }
                }
                if !allHashtags.isEmpty {
                    Section("Хештег") {
                        Picker("Хештег", selection: $filterHashtag) {
                            Text("Все").tag("")
                            ForEach(allHashtags, id: \.self) { tag in
                                Text("#\(tag)").tag(tag)
                            }
                        }
                    }
                }
                Section("Период") {
                    OptionalDatePicker(title: "С", date: $dateFrom)
                    OptionalDatePicker(title: "По", date: $dateTo)
                }
                if hasActiveFilters {
                    Section {
                        Button("Сбросить фильтры", role: .destructive) {
                            filterAccount = nil
                            filterCategory = nil
                            filterHashtag = ""
                            dateFrom = nil
                            dateTo = nil
                        }
                    }
                }
            }
            .navigationTitle("Фильтры")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { showingFilters = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// Переключаемый выбор даты (вкл/выкл границу периода).
struct OptionalDatePicker: View {
    let title: String
    @Binding var date: Date?

    var body: some View {
        Toggle(isOn: Binding(
            get: { date != nil },
            set: { on in date = on ? Date() : nil }
        )) {
            Text(title)
        }
        if let unwrapped = date {
            DatePicker(title, selection: Binding(
                get: { unwrapped },
                set: { date = $0 }
            ), displayedComponents: [.date])
            .labelsHidden()
        }
    }
}

/// Строка операции в списке.
struct TransactionRow: View {
    let tx: Transaction

    private var signedAmount: String {
        let prefix: String
        switch tx.type {
        case .income: prefix = "+"
        case .expense: prefix = "−"
        case .transfer: prefix = ""
        }
        let code = tx.account?.currencyCode ?? ""
        return prefix + Currency.string(tx.amount, code: code)
    }

    private var amountColor: Color {
        switch tx.type {
        case .income: return .green
        case .expense: return .red
        case .transfer: return .blue
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: tx.type.systemImage)
                .font(.title2)
                .foregroundStyle(amountColor)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(tx.date, format: .dateTime.day().month().year().hour().minute())
                    if !tx.hashtags.isEmpty {
                        Text("· " + HashtagParser.display(tx.hashtags))
                            .lineLimit(1)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Text(signedAmount)
                .fontWeight(.semibold)
                .foregroundStyle(amountColor)
        }
        .padding(.vertical, 2)
    }

    private var title: String {
        if tx.type == .transfer {
            let from = tx.account?.name ?? "?"
            let to = tx.destinationAccount?.name ?? "?"
            return "\(from) → \(to)"
        }
        if !tx.details.isEmpty { return tx.details }
        return tx.category?.name ?? tx.type.title
    }
}
