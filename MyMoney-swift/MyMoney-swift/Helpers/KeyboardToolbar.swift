//
//  KeyboardToolbar.swift
//  MyMoney-swift
//
//  Кнопка «Готово» над клавиатурой для закрытия цифровой клавиатуры
//  (у decimalPad/numbersAndPunctuation нет кнопки Return).
//

import SwiftUI
import UIKit

extension View {
    /// Добавляет панель с кнопкой «Готово» над клавиатурой,
    /// скрывающую клавиатуру у любого активного текстового поля.
    func dismissKeyboardButton() -> some View {
        self
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Готово") {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil, from: nil, for: nil)
                    }
                }
            }
    }
}
