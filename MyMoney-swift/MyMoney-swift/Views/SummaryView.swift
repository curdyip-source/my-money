//
//  SummaryView.swift
//  MyMoney-swift
//
//  Финансовая сводка за месяц: кольцевая диаграмма и разбивка по категориям
//  и хештегам. Суммы приводятся к базовой валюте.
//

import SwiftUI
import SwiftData
import Charts

struct SummaryView: View {
    @Query private var transactions: [Transaction]
    @Query private var rates: [CurrencyRate]
    @AppStorage("baseCurrency") private var baseCurrency: String = "RUB"

    enum Granularity { case month, year }

    /// Гранулярность периода: месяц или год.
    @State private var granularity: Granularity = .month
    /// Начало выбранного периода (месяца или года).
    @State private var periodStart: Date = Calendar.current.startOfMonth(for: Date())
    /// true — расходы, false — доходы.
    @State private var showExpenses = true

    private let palette: [Color] = [
        .blue, .green, .orange, .purple, .pink, .red, .teal, .yellow, .indigo, .mint, .brown, .cyan,
    ]

    var body: some View {
        NavigationStack {
            List {
                periodSection
                if monthTransactions.isEmpty {
                    Section {
                        ContentUnavailableView("Нет операций за период", systemImage: "chart.pie")
                    }
                } else {
                    chartSection
                    categoriesSection
                }
            }
            .horizontalScrollPadding()
            .tabBarBottomInset()
            .navigationTitle("Сводка")
        }
    }

    // MARK: - Период и тип

    private var periodSection: some View {
        Section {
            HStack {
                Button { changePeriod(-1) } label: { Image(systemName: "chevron.left") }
                    .buttonStyle(.borderless)
                Spacer()
                // Тап по периоду переключает месяц ⇄ год.
                Button {
                    toggleGranularity()
                } label: {
                    VStack(spacing: 2) {
                        Text(periodLabel)
                            .fontWeight(.semibold)
                        Text(granularity == .month ? "месяц · нажмите для года" : "год · нажмите для месяца")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                Spacer()
                Button { changePeriod(1) } label: { Image(systemName: "chevron.right") }
                    .buttonStyle(.borderless)
                    .disabled(isCurrentPeriod)
            }
            Picker("Тип", selection: $showExpenses) {
                Text("Расходы").tag(true)
                Text("Доходы").tag(false)
            }
            .pickerStyle(.segmented)
        }
    }

    private var periodLabel: String {
        switch granularity {
        case .month: return periodStart.formatted(.dateTime.month(.wide).year())
        case .year: return periodStart.formatted(.dateTime.year())
        }
    }

    // MARK: - Диаграмма

    private var chartSection: some View {
        Section {
            VStack(spacing: 12) {
                Chart(categorySlices) { slice in
                    SectorMark(
                        angle: .value("Сумма", slice.amount),
                        innerRadius: .ratio(0.6),
                        angularInset: 1.5
                    )
                    .foregroundStyle(by: .value("Категория", slice.name))
                    .cornerRadius(3)
                }
                .chartForegroundStyleScale(
                    domain: categorySlices.map(\.name),
                    range: categorySlices.indices.map { palette[$0 % palette.count] }
                )
                .chartLegend(.hidden)
                .frame(height: 220)
                .overlay {
                    VStack(spacing: 2) {
                        Text(showExpenses ? "Расходы" : "Доходы")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(Currency.string(total, code: baseCurrency))
                            .font(.headline)
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - Категории

    private var categoriesSection: some View {
        Section("По категориям") {
            ForEach(Array(categoryGroups.enumerated()), id: \.element.id) { index, group in
                VStack(alignment: .leading, spacing: 6) {
                    // Категория: цвет, название и общая сумма.
                    row(color: palette[index % palette.count], name: group.name, amount: group.amount)
                    // Вложенная разбивка по хештегам — мельче и с отступом.
                    if group.tags.count > 1 || group.tags.first?.name != SummaryCalculator.noHashtagLabel {
                        VStack(alignment: .leading, spacing: 3) {
                            ForEach(group.tags) { tag in
                                hashtagSubRow(name: tag.name, amount: tag.amount)
                            }
                        }
                        .padding(.leading, 20)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func row(color: Color, name: String, amount: Double) -> some View {
        HStack(spacing: 10) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(name)
            Spacer()
            Text(Currency.string(amount, code: baseCurrency))
                .fontWeight(.medium)
            if total > 0 {
                Text("\(Int((amount / total * 100).rounded()))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 44, alignment: .trailing)
            }
        }
    }

    /// Строка хештега внутри категории (мелким шрифтом).
    private func hashtagSubRow(name: String, amount: Double) -> some View {
        HStack(spacing: 6) {
            Text(name == SummaryCalculator.noHashtagLabel ? name : "#\(name)")
                .foregroundStyle(.secondary)
            Spacer()
            Text(Currency.string(amount, code: baseCurrency))
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    // MARK: - Данные

    private var ratesDict: [String: Double] {
        Dictionary(rates.map { ($0.code, $0.rate) }, uniquingKeysWith: { a, _ in a })
    }

    private var monthTransactions: [Transaction] {
        let cal = Calendar.current
        let start = periodStart
        let component: Calendar.Component = granularity == .month ? .month : .year
        let end = cal.date(byAdding: component, value: 1, to: start) ?? start
        let neededType: TransactionType = showExpenses ? .expense : .income
        return transactions.filter { $0.type == neededType && $0.date >= start && $0.date < end }
    }

    private var categorySlices: [SummaryCalculator.Slice] {
        SummaryCalculator.byCategory(monthTransactions, baseCurrency: baseCurrency, rates: ratesDict)
    }

    private var categoryGroups: [SummaryCalculator.CategoryGroup] {
        SummaryCalculator.byCategoryDetailed(monthTransactions, baseCurrency: baseCurrency, rates: ratesDict)
    }

    private var total: Double {
        categorySlices.reduce(0) { $0 + $1.amount }
    }

    private var isCurrentPeriod: Bool {
        let comp: Calendar.Component = granularity == .month ? .month : .year
        return Calendar.current.isDate(periodStart, equalTo: Date(), toGranularity: comp)
    }

    private func changePeriod(_ delta: Int) {
        let cal = Calendar.current
        let comp: Calendar.Component = granularity == .month ? .month : .year
        if let new = cal.date(byAdding: comp, value: delta, to: periodStart) {
            periodStart = normalize(new)
        }
    }

    private func toggleGranularity() {
        granularity = granularity == .month ? .year : .month
        periodStart = normalize(periodStart)
    }

    /// Приводит дату к началу периода (месяца или года).
    private func normalize(_ date: Date) -> Date {
        let cal = Calendar.current
        switch granularity {
        case .month: return cal.startOfMonth(for: date)
        case .year:
            return cal.date(from: cal.dateComponents([.year], from: date)) ?? date
        }
    }
}

extension Calendar {
    /// Начало месяца для заданной даты.
    func startOfMonth(for date: Date) -> Date {
        self.date(from: dateComponents([.year, .month], from: date)) ?? date
    }
}
