//
//  KeyboardDismissTap.swift
//  MyMoney-swift
//
//  Глобальное закрытие клавиатуры тапом в любом месте вне клавиатуры.
//  Жест вешается на окно один раз; cancelsTouchesInView = false, поэтому
//  нажатия на кнопки и ячейки продолжают работать как обычно.
//

import SwiftUI
import UIKit

final class KeyboardDismissTapManager: NSObject, UIGestureRecognizerDelegate {
    static let shared = KeyboardDismissTapManager()
    private var installed = false

    /// Устанавливает жест на ключевое окно (идемпотентно).
    func install() {
        guard !installed,
              let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene }).first,
              let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first
        else { return }

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        tap.cancelsTouchesInView = false
        tap.delegate = self
        window.addGestureRecognizer(tap)
        installed = true
    }

    @objc private func handleTap() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    /// Позволяем жесту работать одновременно с прочими (скролл, нажатия и т.п.).
    nonisolated func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }
}
