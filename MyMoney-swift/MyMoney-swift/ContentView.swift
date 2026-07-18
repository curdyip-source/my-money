//
//  ContentView.swift
//  MyMoney-swift
//
//  Корневой экран: три экрана (Счета, Операции, Настройки) с нижней панелью
//  навигации И горизонтальным свайпом между ними.
//
//  Свайп реализован нативным пейджингом iOS 17+:
//  ScrollView(.horizontal) + .scrollTargetBehavior(.paging) + .scrollTargetLayout(),
//  без TabView и без кастомного DragGesture. Позиция прокрутки двусторонне
//  связана с нижней панелью: свайп меняет активную вкладку, тап по вкладке
//  прокручивает к нужному экрану.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Query private var categories: [TransactionCategory]

    /// Индекс текущего экрана (он же id страницы в пейджере).
    @State private var current: Int? = 0
    /// Одноразовый переход на «Операции» при первом запуске (см. `.onAppear`).
    @State private var didSelectDefaultTab = false
    /// Измеренная высота нижней панели — прокидывается спискам, чтобы контент
    /// не уходил под неё.
    @State private var barHeight: CGFloat = 0

    var body: some View {
        ScrollView(.horizontal) {
            // Не ленивый HStack: при старте пейджер прокручивается к «Операциям»
            // (индекс 1); с LazyHStack целевая страница не успевает создаться и
            // экран остаётся белым, поэтому держим все страницы построенными.
            HStack(spacing: 0) {
                AccountsView()
                    .containerRelativeFrame(.horizontal)
                    .id(0)
                TransactionsView()
                    .containerRelativeFrame(.horizontal)
                    .id(1)
                SummaryView()
                    .containerRelativeFrame(.horizontal)
                    .id(2)
                DebtsView()
                    .containerRelativeFrame(.horizontal)
                    .id(3)
                SettingsView()
                    .containerRelativeFrame(.horizontal)
                    .id(4)
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $current)
        .scrollIndicators(.hidden)
        .ignoresSafeArea(.keyboard)
        .onAppear {
            // Открываем «Операции» (индекс 1) по умолчанию. Делаем это после
            // первой раскладки и без анимации: заданная сразу начальная позиция
            // на пейджере не применяется к прокрутке, только к панели вкладок.
            guard !didSelectDefaultTab else { return }
            didSelectDefaultTab = true
            DispatchQueue.main.async {
                var tx = SwiftUI.Transaction()
                tx.disablesAnimations = true
                withTransaction(tx) { current = 1 }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BottomTabBar(selection: Binding(
                get: { current ?? 0 },
                set: { newValue in withAnimation(.easeInOut(duration: 0.25)) { current = newValue } }
            ))
            .background {
                GeometryReader { proxy in
                    // Полная высота, перекрываемая панелью: её контент плюс нижняя
                    // безопасная зона (home indicator), которую пейджер не
                    // прокидывает вложенным спискам.
                    let occluded = proxy.size.height + proxy.safeAreaInsets.bottom
                    Color.clear
                        .onAppear { barHeight = occluded }
                        .onChange(of: occluded) { _, h in barHeight = h }
                }
            }
        }
        .environment(\.tabBarHeight, barHeight)
        .task {
            KeyboardDismissTapManager.shared.install()
            seedDefaultCategoriesIfNeeded()
        }
    }

    /// При первом запуске создаём базовый список категорий.
    private func seedDefaultCategoriesIfNeeded() {
        guard categories.isEmpty else { return }
        for (name, icon) in TransactionCategory.defaults {
            context.insert(TransactionCategory(name: name, systemImage: icon))
        }
        try? context.save()
    }
}

/// Нижняя панель навигации (тап переключает экран, синхронизирована со свайпом).
private struct BottomTabBar: View {
    @Binding var selection: Int

    private let items: [(title: String, icon: String)] = [
        ("Счета", "wallet.bifold"),
        ("Операции", "list.bullet.rectangle"),
        ("Сводка", "chart.pie"),
        ("Долги", "person.2"),
        ("Настройки", "gearshape"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 0) {
                ForEach(items.indices, id: \.self) { index in
                    Button {
                        selection = index
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: items[index].icon)
                                .font(.system(size: 22))
                            Text(items[index].title)
                                .font(.caption2)
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(selection == index ? Color.accentColor : Color.secondary)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 8)
        }
        .background(.bar, ignoresSafeAreaEdges: .bottom)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Account.self, Transaction.self, TransactionCategory.self,
                              CurrencyRate.self, Debt.self],
                        inMemory: true)
}
