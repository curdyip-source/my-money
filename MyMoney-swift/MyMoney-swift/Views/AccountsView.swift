//
//  AccountsView.swift
//  MyMoney-swift
//
//  Список счетов с автоматически пересчитываемыми балансами и общим итогом.
//

import SwiftUI
import SwiftData

struct AccountsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Account.createdAt) private var accounts: [Account]
    @Query private var transactions: [Transaction]
    @Query private var rates: [CurrencyRate]

    @AppStorage("baseCurrency") private var baseCurrency: String = "RUB"

    @State private var editingAccount: Account?
    @State private var showingNewAccount = false
    @State private var accountToDelete: Account?

    /// Суммы скрыты по умолчанию; показываются по нажатию на «(показать)» у заголовка.
    @State private var showBalances = false

    var body: some View {
        NavigationStack {
            List {
                if accounts.isEmpty {
                    ContentUnavailableView(
                        "Нет счетов",
                        systemImage: "wallet.bifold",
                        description: Text("Добавьте первый счёт кнопкой «+»")
                    )
                } else {
                    totalsSection
                    accountsSection
                }
            }
            .horizontalScrollPadding()
            .tabBarBottomInset()
            .navigationTitle("Счета")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingNewAccount = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewAccount) {
                AccountFormView()
            }
            .sheet(item: $editingAccount) { account in
                AccountFormView(account: account)
            }
            .confirmationDialog(
                "Удалить счёт?",
                isPresented: Binding(get: { accountToDelete != nil },
                                     set: { if !$0 { accountToDelete = nil } }),
                titleVisibility: .visible,
                presenting: accountToDelete
            ) { account in
                Button("Удалить", role: .destructive) {
                    delete(account)
                    accountToDelete = nil
                }
                Button("Отмена", role: .cancel) { accountToDelete = nil }
            } message: { account in
                Text("Счёт «\(account.name)» и все операции по нему будут удалены без возможности восстановления.")
            }
        }
    }

    // MARK: - Итоги

    private var ratesDict: [String: Double] {
        Dictionary(rates.map { ($0.code, $0.rate) }, uniquingKeysWith: { a, _ in a })
    }

    private var totalsSection: some View {
        Section {
            let totals = BalanceCalculator.totalsByCurrency(accounts: accounts, transactions: transactions)
            ForEach(totals.keys.sorted(), id: \.self) { code in
                HStack {
                    Text(code)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(masked(totals[code] ?? 0, code: code))
                        .fontWeight(.semibold)
                }
            }

            let converted = BalanceCalculator.convertedTotal(
                accounts: accounts, transactions: transactions,
                baseCurrency: baseCurrency, rates: ratesDict)
            if totals.keys.count > 1 {
                HStack {
                    Text("Итого в \(baseCurrency)")
                        .fontWeight(.semibold)
                    Spacer()
                    Text(masked(converted.total, code: baseCurrency))
                        .fontWeight(.bold)
                }
                if !converted.missing.isEmpty {
                    Text("Нет курса для: \(converted.missing.joined(separator: ", ")). Задайте курс в «Настройках».")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        } header: {
            HStack {
                Text("Общий баланс")
                Spacer()
                // Глазок показывает/скрывает все суммы на экране.
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showBalances.toggle() }
                } label: {
                    Image(systemName: showBalances ? "eye" : "eye.slash")
                        .imageScale(.large)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(showBalances ? "Скрыть суммы" : "Показать суммы")
            }
        }
    }

    private var accountsSection: some View {
        Section("Счета") {
            ForEach(accounts) { account in
                NavigationLink {
                    AccountDetailView(account: account)
                } label: {
                    AccountRow(account: account,
                               balance: BalanceCalculator.balance(for: account, transactions: transactions),
                               hidden: !showBalances)
                }
                .contextMenu {
                    Button {
                        editingAccount = account
                    } label: {
                        Label("Изменить", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        accountToDelete = account
                    } label: {
                        Label("Удалить", systemImage: "trash")
                    }
                }
            }
        }
    }

    /// Сумма или маска «••••», если показ сумм выключен.
    private func masked(_ amount: Double, code: String) -> String {
        showBalances ? Currency.string(amount, code: code) : "••••"
    }

    // MARK: - Действия

    private func delete(_ account: Account) {
        // Удаляем связанные операции, чтобы не оставить «висящих» ссылок.
        for tx in transactions where tx.account?.uid == account.uid || tx.destinationAccount?.uid == account.uid {
            context.delete(tx)
        }
        context.delete(account)
        try? context.save()
    }
}

/// Строка счёта в списке.
struct AccountRow: View {
    let account: Account
    let balance: Double
    /// Скрыть денежные суммы (показывать маску «••••»).
    var hidden: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: account.type.systemImage)
                .font(.title2)
                .frame(width: 36)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(account.name)
                    .font(.body)
                Text(account.type.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(hidden ? "••••" : Currency.string(balance, code: account.currencyCode))
                    .fontWeight(.semibold)
                    .foregroundStyle(balance < 0 && !hidden ? .red : .primary)
                if account.type == .creditCard, let limit = account.creditLimit {
                    Text("Доступно: \(hidden ? "••••" : Currency.string(limit + balance, code: account.currencyCode))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
