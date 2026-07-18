//
//  AccountDetailView.swift
//  MyMoney-swift
//
//  Детали счёта: текущий баланс и список операций по нему.
//

import SwiftUI
import SwiftData

struct AccountDetailView: View {
    let account: Account

    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    @State private var editingTransaction: Transaction?

    private var transactions: [Transaction] {
        allTransactions.filter {
            $0.account?.uid == account.uid || $0.destinationAccount?.uid == account.uid
        }
    }

    private var balance: Double {
        BalanceCalculator.balance(for: account, transactions: allTransactions)
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Текущий баланс")
                    Spacer()
                    Text(Currency.string(balance, code: account.currencyCode))
                        .fontWeight(.bold)
                        .foregroundStyle(balance < 0 ? .red : .primary)
                }
                LabeledContent("Тип", value: account.type.title)
                LabeledContent("Валюта", value: account.currencyCode)
                if account.type == .creditCard, let limit = account.creditLimit {
                    LabeledContent("Кредитный лимит",
                                   value: Currency.string(limit, code: account.currencyCode))
                    LabeledContent("Доступно",
                                   value: Currency.string(limit + balance, code: account.currencyCode))
                }
            }

            Section("Операции (\(transactions.count))") {
                if transactions.isEmpty {
                    Text("Операций по счёту пока нет")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(transactions) { tx in
                        Button {
                            editingTransaction = tx
                        } label: {
                            TransactionRow(tx: tx)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .horizontalScrollPadding()
        .navigationTitle(account.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingTransaction) { tx in
            TransactionFormView(transaction: tx)
        }
    }
}
