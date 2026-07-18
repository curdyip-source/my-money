//
//  CategoriesView.swift
//  MyMoney-swift
//
//  Управление редактируемым списком категорий.
//

import SwiftUI
import SwiftData

struct CategoriesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \TransactionCategory.name) private var categories: [TransactionCategory]

    @State private var newName: String = ""
    @State private var editingCategory: TransactionCategory?
    @State private var categoryToDelete: TransactionCategory?

    var body: some View {
        List {
            Section("Добавить категорию") {
                HStack {
                    TextField("Название", text: $newName)
                    Button("Добавить") {
                        addCategory()
                    }
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            Section("Категории") {
                ForEach(categories) { cat in
                    Button {
                        editingCategory = cat
                    } label: {
                        Label(cat.name, systemImage: cat.systemImage)
                            .foregroundStyle(.primary)
                    }
                    .contextMenu {
                        Button {
                            editingCategory = cat
                        } label: {
                            Label("Переименовать", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            categoryToDelete = cat
                        } label: {
                            Label("Удалить", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle("Категории")
        .alert("Переименовать категорию", isPresented: Binding(
            get: { editingCategory != nil },
            set: { if !$0 { editingCategory = nil } }
        )) {
            CategoryRenameField(category: editingCategory) { try? context.save() }
            Button("Отмена", role: .cancel) { editingCategory = nil }
        }
        .confirmationDialog(
            "Удалить категорию?",
            isPresented: Binding(get: { categoryToDelete != nil },
                                 set: { if !$0 { categoryToDelete = nil } }),
            titleVisibility: .visible,
            presenting: categoryToDelete
        ) { cat in
            Button("Удалить", role: .destructive) {
                delete(cat)
                categoryToDelete = nil
            }
            Button("Отмена", role: .cancel) { categoryToDelete = nil }
        } message: { cat in
            Text("Категория «\(cat.name)» будет удалена. У операций с этой категорией она станет пустой.")
        }
    }

    private func addCategory() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        context.insert(TransactionCategory(name: name))
        try? context.save()
        newName = ""
    }

    private func delete(_ category: TransactionCategory) {
        context.delete(category)
        try? context.save()
    }
}

/// Текстовое поле для переименования внутри alert.
private struct CategoryRenameField: View {
    let category: TransactionCategory?
    let onCommit: () -> Void
    @State private var text: String = ""

    var body: some View {
        TextField("Название", text: $text)
            .onAppear { text = category?.name ?? "" }
        Button("Сохранить") {
            if let category {
                category.name = text.trimmingCharacters(in: .whitespaces)
                onCommit()
            }
        }
    }
}
