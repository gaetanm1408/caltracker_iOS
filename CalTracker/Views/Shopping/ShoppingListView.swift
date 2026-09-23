import SwiftData
import SwiftUI

struct ShoppingListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\ShoppingListItem.sortIndex)]) private var items: [ShoppingListItem]
    @Query(sort: [SortDescriptor(\Recipe.name)]) private var recipes: [Recipe]

    @State private var isPresentingGenerator = false
    @State private var isPresentingPlanner = false
    @State private var isPresentingManualItem = false

    private var pending: [ShoppingListItem] { items.filter { !$0.isChecked } }
    private var done: [ShoppingListItem] { items.filter(\.isChecked) }

    private var service: ShoppingListService {
        ShoppingListService(context: context)
    }

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    ContentUnavailableView {
                        Label("Liste vide", systemImage: "cart")
                    } description: {
                        Text("Génère ta liste à partir de tes recettes : les ingrédients identiques sont regroupés automatiquement.")
                    } actions: {
                        Button("Composer un menu") {
                            isPresentingPlanner = true
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(recipes.isEmpty)
                    }
                } else {
                    List {
                        Section {
                            ForEach(pending) { item in
                                ShoppingListRow(item: item) { toggle(item) }
                            }
                            .onDelete { delete(pending, at: $0) }
                        } header: {
                            Text("À acheter (\(pending.count))")
                        }

                        if !done.isEmpty {
                            Section {
                                ForEach(done) { item in
                                    ShoppingListRow(item: item) { toggle(item) }
                                }
                                .onDelete { delete(done, at: $0) }
                            } header: {
                                HStack {
                                    Text("Dans le panier (\(done.count))")
                                    Spacer()
                                    Button("Vider") {
                                        withAnimation { try? service.clearChecked() }
                                    }
                                    .font(.caption)
                                    .textCase(nil)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Courses")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !items.isEmpty {
                        ShareLink(item: service.shareText(for: items)) {
                            Label("Partager", systemImage: "square.and.arrow.up")
                        }
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        isPresentingManualItem = true
                    } label: {
                        Label("Ajouter un article", systemImage: "plus")
                    }
                    Menu {
                        Button {
                            isPresentingPlanner = true
                        } label: {
                            Label("Composer un menu", systemImage: "calendar")
                        }
                        Button {
                            isPresentingGenerator = true
                        } label: {
                            Label("Choisir mes recettes", systemImage: "checklist")
                        }
                    } label: {
                        Label("Générer", systemImage: "wand.and.stars")
                    }
                    .disabled(recipes.isEmpty)
                }
            }
            .sheet(isPresented: $isPresentingGenerator) {
                NavigationStack {
                    ShoppingListGeneratorView(recipes: recipes)
                }
            }
            .sheet(isPresented: $isPresentingPlanner) {
                NavigationStack {
                    MealPlannerView(recipes: recipes)
                }
            }
            .sheet(isPresented: $isPresentingManualItem) {
                NavigationStack {
                    ManualShoppingItemSheet()
                }
                .presentationDetents([.medium])
            }
        }
    }

    private func toggle(_ item: ShoppingListItem) {
        withAnimation { service.toggle(item) }
    }

    private func delete(_ source: [ShoppingListItem], at offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                service.delete(source[index])
            }
        }
    }
}

struct ShoppingListRow: View {
    let item: ShoppingListItem
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isChecked ? Color.accentColor : Color.secondary)
                    .imageScale(.large)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .strikethrough(item.isChecked)
                        .foregroundStyle(item.isChecked ? .secondary : .primary)
                    if let origin = item.originDescription {
                        Text(origin)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Text(item.quantityDescription)
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Adds an article that comes from no recipe.
private struct ManualShoppingItemSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var quantityText = "1"
    @State private var unit: MeasurementUnit = .piece

    private var quantity: Double {
        Double.parseUserInput(quantityText) ?? 0
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && quantity > 0
    }

    var body: some View {
        Form {
            TextField("Article", text: $name)
            HStack {
                TextField("Quantité", text: $quantityText)
                    .keyboardType(.decimalPad)
                Picker("Unité", selection: $unit) {
                    ForEach(MeasurementUnit.allCases) { unit in
                        Text(unit.displayName).tag(unit)
                    }
                }
                .labelsHidden()
            }
        }
        .navigationTitle("Nouvel article")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Annuler") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Ajouter") {
                    try? ShoppingListService(context: context).addManualItem(
                        name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                        quantity: quantity,
                        unit: unit
                    )
                    dismiss()
                }
                .disabled(!isValid)
            }
        }
    }
}

#Preview {
    ShoppingListView()
        .modelContainer(PreviewData.container())
}
