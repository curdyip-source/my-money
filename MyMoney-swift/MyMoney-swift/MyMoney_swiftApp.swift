//
//  MyMoney_swiftApp.swift
//  MyMoney-swift
//
//  Created by Александр Воробьев on 29.06.2026.
//

import SwiftUI
import SwiftData
import UIKit

@main
struct MyMoney_swiftApp: App {
    /// Контейнер локального хранилища SwiftData (полностью офлайн, на устройстве).
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(
                for: Account.self, Transaction.self, TransactionCategory.self,
                     CurrencyRate.self, Debt.self
            )
        } catch {
            fatalError("Не удалось создать локальное хранилище: \(error)")
        }

        // Левый отступ заголовков навигации, чтобы они не прилегали к краю экрана.
        UINavigationBar.appearance().layoutMargins = UIEdgeInsets(
            top: 0, left: 28, bottom: 0, right: 16)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
