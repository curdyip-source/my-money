//
//  DebtsView.swift
//  MyMoney-swift
//
//  Реестр долгов: «Мне должны» и «Я должен», с итогами по валютам.
//

import SwiftUI
import SwiftData

struct DebtsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Debt.date, order: .reverse) private var debts: [Debt]

    @State private var showingNew = false
    @State private var editingDebt: Debt?
    @State private var debtToDelete: Debt?
    @State private var repayingDebt: Debt?

    private var owedToMe: [Debt] { debts.filter { $0.isOwedToMe && !$0.isSettled } }
    private var iOwe: [Debt] { debts.filter { !$0.isOwedToMe && !$0.isSettled } }
    private var settled: [Debt] { debts.filter { $0.isSettled } }

    var body: some View {
        NavigationStack {
            Group {
                if debts.isEmpty {
                    ContentUnavailableView(
                        "Нет долгов",
                        systemImage: "person.2",
                        description: Text("Добавьте долг кнопкой «+»: кто кому и сколько должен")
                    )
                } else {
                    list
                }
            }
            .navigationTitle("Долги")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingNew = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showingNew) { DebtFormView() }
            .sheet(item: $editingDebt) { debt in DebtFormView(debt: debt) }
            .sheet(item: $repayingDebt) { debt in DebtRepaymentView(debt: debt) }
            .confirmationDialog(
                "Удалить долг?",
                isPresented: Binding(get: { debtToDelete != nil },
                                     set: { if !$0 { debtToDelete = nil } }),
                titleVisibility: .visible,
                presenting: debtToDelete
            ) { debt in
                Button("Удалить", role: .destructive) {
                    context.delete(debt)
                    try? context.save()
                    debtToDelete = nil
                }
                Button("Отмена", role: .cancel) { debtToDelete = nil }
            } message: { debt in
                Text("Долг «\(debt.person)» будет удалён без возможности восстановления.")
            }
        }
    }

    private var list: some View {
        List {
            if !owedToMe.isEmpty {
                Section {
                    ForEach(owedToMe) { debtRow($0) }
                } header: {
                    sectionHeader("Мне должны", debts: owedToMe, positive: true)
                }
            }
            if !iOwe.isEmpty {
                Section {
                    ForEach(iOwe) { debtRow($0) }
                } header: {
                    sectionHeader("Я должен", debts: iOwe, positive: false)
                }
            }
            if !settled.isEmpty {
                Section("Погашенные") {
                    ForEach(settled) { debtRow($0) }
                }
            }
        }
        .horizontalScrollPadding()
        .tabBarBottomInset()
    }

    private func sectionHeader(_ title: String, debts: [Debt], positive: Bool) -> some View {
        let totals = Dictionary(grouping: debts, by: { $0.currencyCode })
            .mapValues { $0.reduce(0) { $0 + $1.remaining } }
        return HStack {
            Text(title)
            Spacer()
            Text(totals.keys.sorted().map { Currency.string(totals[$0] ?? 0, code: $0) }
                .joined(separator: " · "))
                .foregroundStyle(positive ? .green : .red)
        }
    }

    private func debtRow(_ debt: Debt) -> some View {
        Button {
            editingDebt = debt
        } label: {
            HStack(spacing: 12) {
                Image(systemName: debt.isOwedToMe ? "arrow.down.left.circle.fill" : "arrow.up.right.circle.fill")
                    .font(.title2)
                    .foregroundStyle(debt.isOwedToMe ? .green : .red)
                VStack(alignment: .leading, spacing: 4) {
                    Text(debt.person.isEmpty ? "Без имени" : debt.person)
                        .strikethrough(debt.isSettled)
                    HStack(spacing: 6) {
                        Text(debt.date, format: .dateTime.day().month().year())
                        if let due = debt.dueDate {
                            Text("· до \(due.formatted(.dateTime.day().month()))")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    if !debt.note.isEmpty {
                        Text(debt.note).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    // Прогресс частичного погашения.
                    if debt.repaidAmount > 0 && !debt.isSettled {
                        ProgressView(value: debt.progress)
                            .tint(debt.isOwedToMe ? .green : .red)
                        Text("Погашено \(Currency.string(debt.repaidAmount, code: debt.currencyCode)) из \(Currency.string(debt.amount, code: debt.currencyCode))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text(Currency.string(debt.isSettled ? debt.amount : debt.remaining, code: debt.currencyCode))
                    .fontWeight(.semibold)
                    .foregroundStyle(debt.isSettled ? .secondary : .primary)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            if !debt.isSettled {
                Button {
                    repayingDebt = debt
                } label: {
                    Label("Погасить (полностью или частью)…", systemImage: "checkmark.circle")
                }
            }
            Button {
                editingDebt = debt
            } label: {
                Label("Изменить", systemImage: "pencil")
            }
            Button(role: .destructive) {
                debtToDelete = debt
            } label: {
                Label("Удалить", systemImage: "trash")
            }
        }
    }
}
