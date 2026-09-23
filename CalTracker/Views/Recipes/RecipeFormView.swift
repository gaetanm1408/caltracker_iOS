import SwiftData
import SwiftUI

/// Editable copy of a recipe ingredient, so the form can be cancelled without
/// leaving half-created objects in the store.
struct IngredientDraft: Identifiable, Hashable {
    let id: UUID
    var name: String
    var quantity: Double
    var unit: MeasurementUnit
    var isPantryStaple: Bool
    var barcode: String?
    var gramsPerPiece: Double?
    var nutritionPer100g: NutritionFacts?

    init(
        id: UUID = UUID(),
        name: String,
        quantity: Double,
        unit: MeasurementUnit,
        isPantryStaple: Bool = false,
        barcode: String? = nil,
        gramsPerPiece: Double? = nil,
        nutritionPer100g: NutritionFacts? = nil
    ) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.isPantryStaple = isPantryStaple
        self.barcode = barcode
        self.gramsPerPiece = gramsPerPiece
        self.nutritionPer100g = nutritionPer100g
    }

    init(ingredient: RecipeIngredient) {
        self.init(
            id: ingredient.id,
            name: ingredient.name,
            quantity: ingredient.quantity,
            unit: ingredient.unit,
            isPantryStaple: ingredient.isPantryStaple,
            barcode: ingredient.barcode,
            gramsPerPiece: ingredient.gramsPerPiece,
            nutritionPer100g: ingredient.nutritionPer100g
        )
    }

    var quantityDescription: String {
        "\(QuantityFormatter.string(from: quantity)) \(unit.displayName)"
    }

    /// Même règle que `RecipeIngredient` : une pièce ne pèse que si son poids
    /// unitaire est connu.
    var quantityInGrams: Double? {
        switch unit.dimension {
        case .mass, .volume:
            return quantity * unit.baseUnitFactor
        case .count:
            guard let gramsPerPiece, gramsPerPiece > 0 else { return nil }
            return quantity * gramsPerPiece
        }
    }
}

struct RecipeFormView: View {
    /// `nil` creates a new recipe.
    var recipe: Recipe?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var summary = ""
    @State private var instructions = ""
    @State private var servings = 2
    @State private var preparationMinutes = 0
    @State private var category: RecipeCategory = .meal
    @State private var drafts: [IngredientDraft] = []
    @State private var isPresentingIngredientPicker = false
    @State private var didLoad = false

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var draftNutritionPerServing: NutritionFacts {
        let total = drafts.reduce(NutritionFacts.zero) { partial, draft in
            guard let facts = draft.nutritionPer100g, let grams = draft.quantityInGrams else {
                return partial
            }
            return partial + NutritionCalculator.nutrition(for: facts, quantityInGrams: grams)
        }
        return total.scaled(by: 1 / Double(max(1, servings)))
    }

    var body: some View {
        Form {
            Section("Recette") {
                TextField("Nom", text: $name)
                Picker("Type", selection: $category) {
                    ForEach(RecipeCategory.allCases) { category in
                        Text(category.localizedName).tag(category)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                TextField("Description courte", text: $summary, axis: .vertical)
                    .lineLimit(1...3)
                Stepper("Portions : \(servings)", value: $servings, in: 1...20)
                Stepper(
                    preparationMinutes > 0
                        ? "Préparation : \(preparationMinutes) min"
                        : "Préparation : non renseignée",
                    value: $preparationMinutes,
                    in: 0...240,
                    step: 5
                )
            }

            Section {
                if drafts.isEmpty {
                    Text("Aucun ingrédient.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach($drafts) { $draft in
                        IngredientDraftRow(draft: $draft)
                    }
                    .onDelete { drafts.remove(atOffsets: $0) }
                    .onMove { drafts.move(fromOffsets: $0, toOffset: $1) }
                }

                Button {
                    isPresentingIngredientPicker = true
                } label: {
                    Label("Ajouter un ingrédient", systemImage: "plus.circle")
                }
            } header: {
                HStack {
                    Text("Ingrédients")
                    Spacer()
                    if !drafts.isEmpty {
                        EditButton()
                            .font(.caption)
                            .textCase(nil)
                    }
                }
            } footer: {
                if draftNutritionPerServing.calories > 0 {
                    Text("Environ \(QuantityFormatter.calories(draftNutritionPerServing.calories)) par portion.")
                }
            }

            Section("Préparation") {
                TextField("Étapes de la recette", text: $instructions, axis: .vertical)
                    .lineLimit(4...12)
            }
        }
        .navigationTitle(recipe == nil ? "Nouvelle recette" : "Modifier")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Annuler") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Enregistrer", action: save)
                    .disabled(!isValid)
            }
        }
        .sheet(isPresented: $isPresentingIngredientPicker) {
            NavigationStack {
                IngredientPickerView { draft in
                    drafts.append(draft)
                }
            }
        }
        .onAppear(perform: loadIfNeeded)
    }

    private func loadIfNeeded() {
        guard !didLoad, let recipe else {
            didLoad = true
            return
        }
        name = recipe.name
        summary = recipe.summary
        instructions = recipe.instructions
        servings = recipe.servings
        preparationMinutes = recipe.preparationMinutes
        category = recipe.category
        drafts = recipe.ingredients
            .sorted { $0.sortIndex < $1.sortIndex }
            .map(IngredientDraft.init(ingredient:))
        didLoad = true
    }

    private func save() {
        let service = RecipeService(context: context)
        let target = recipe ?? service.create(name: name, servings: servings)

        target.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        target.summary = summary
        target.instructions = instructions
        target.servings = servings
        target.preparationMinutes = preparationMinutes
        target.category = category

        syncIngredients(of: target, using: service)
        dismiss()
    }

    /// Applies the draft list to the persisted ingredients: removals first,
    /// then updates, then insertions, keeping the drag-and-drop order.
    private func syncIngredients(of recipe: Recipe, using service: RecipeService) {
        let draftIDs = Set(drafts.map(\.id))
        for ingredient in recipe.ingredients where !draftIDs.contains(ingredient.id) {
            service.removeIngredient(ingredient, from: recipe)
        }

        let existing = Dictionary(
            recipe.ingredients.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        for (index, draft) in drafts.enumerated() {
            if let ingredient = existing[draft.id] {
                ingredient.name = draft.name
                ingredient.quantity = draft.quantity
                ingredient.unit = draft.unit
                ingredient.isPantryStaple = draft.isPantryStaple
                ingredient.gramsPerPiece = draft.gramsPerPiece
                ingredient.sortIndex = index
            } else {
                let created = service.addIngredient(
                    to: recipe,
                    name: draft.name,
                    quantity: draft.quantity,
                    unit: draft.unit,
                    isPantryStaple: draft.isPantryStaple,
                    gramsPerPiece: draft.gramsPerPiece,
                    nutritionPer100g: draft.nutritionPer100g,
                    barcode: draft.barcode
                )
                created.sortIndex = index
            }
        }
    }
}

private struct IngredientDraftRow: View {
    @Binding var draft: IngredientDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                TextField("Ingrédient", text: $draft.name)
                Spacer(minLength: 8)
                TextField(
                    "0",
                    value: $draft.quantity,
                    format: .number.precision(.fractionLength(0...1))
                )
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 60)
                Picker("Unité", selection: $draft.unit) {
                    ForEach(MeasurementUnit.allCases) { unit in
                        Text(unit.displayName).tag(unit)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

            if draft.unit.dimension == .count {
                HStack {
                    Text("Poids unitaire")
                    Spacer()
                    TextField(
                        "—",
                        value: $draft.gramsPerPiece,
                        format: .number.precision(.fractionLength(0...1))
                    )
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 60)
                    Text("g").foregroundStyle(.secondary)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Toggle("Produit de placard", isOn: $draft.isPantryStaple)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack {
        RecipeFormView()
    }
    .modelContainer(PreviewData.container())
}
