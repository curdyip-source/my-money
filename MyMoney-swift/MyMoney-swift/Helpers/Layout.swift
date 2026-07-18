//
//  Layout.swift
//  MyMoney-swift
//
//  Общие модификаторы оформления.
//

import SwiftUI

extension View {
    /// Горизонтальные отступы для прокручиваемого контента (List/ScrollView),
    /// чтобы содержимое не прилегало вплотную к краям экрана.
    func horizontalScrollPadding(_ amount: CGFloat = 16) -> some View {
        contentMargins(.horizontal, amount, for: .scrollContent)
    }

    /// Нижний отступ прокручиваемого контента на высоту таб-бара, чтобы
    /// последние строки списка не уходили под нижнюю панель навигации.
    func tabBarBottomInset() -> some View {
        modifier(TabBarBottomInset())
    }
}

/// Высота нижней панели навигации, измеряется в `ContentView` и прокидывается
/// в дерево, чтобы списки могли зарезервировать под неё место.
private struct TabBarHeightKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var tabBarHeight: CGFloat {
        get { self[TabBarHeightKey.self] }
        set { self[TabBarHeightKey.self] = newValue }
    }
}

private struct TabBarBottomInset: ViewModifier {
    @Environment(\.tabBarHeight) private var height

    func body(content: Content) -> some View {
        content.contentMargins(.bottom, height + 8, for: .scrollContent)
    }
}

/// Простая раскладка «с переносом»: элементы идут в ряд, а не помещающиеся
/// переносятся на новую строку. Используется для чипсов-хештегов.
struct WrapLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth > 0, rowWidth + spacing + size.width > maxWidth {
                totalHeight += rowHeight + spacing
                totalWidth = max(totalWidth, rowWidth)
                rowWidth = size.width
                rowHeight = size.height
            } else {
                rowWidth += (rowWidth > 0 ? spacing : 0) + size.width
                rowHeight = max(rowHeight, size.height)
            }
        }
        totalHeight += rowHeight
        totalWidth = max(totalWidth, rowWidth)
        return CGSize(width: min(totalWidth, maxWidth), height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let maxWidth = bounds.width
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.minX + maxWidth {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading,
                          proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
