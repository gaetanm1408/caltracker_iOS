import SwiftData
import SwiftUI

/// Picks a quantity and a meal, then writes the entry to the journal.
struct AddFoodSheet: View {
    private enum Source {
        case remote(RemoteFood)
        case stored(FoodProduct)
    }

    private let source: Source
    private let targetDate: Date
    private let onLogged: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var quantityText: String = "100"
    @State private var meal: MealType = .snack
    @State private var errorMessage: String?

    init(food: RemoteFood, targetDate: Date = .now, onLogged: @escaping () -> Void = {}) {
        self.source = .remote(food)
        self.targetDate = targetDate
        self.onLogged = onLogged
    }

    init(product: FoodProduct, targetDate: Date = .now, onLogged: @escaping () -> Void = {}) {
        self.source = .stored(product)
        self.targetDate = targetDate
        self.onLogged = onLogged
    }

    private var name: String {
        switch source {
        case .remote(let food): return food.name
        case .stored(let product): return product.name
        }
    }

    private var brand: String? {
        switch source {
        case .remote(let food): return food.brand
        case .stored(let product): return product.brand
        }
    }

    private var nutritionPer100g: NutritionFacts {
        switch source {
        case .remote(let food): return food.nutritionPer100g
        case .stored(let product): return product.nutritionPer100g
        }
    }

    private var servingSize: Double? {
        switch source {
        case .remote(let food): return food.servingSizeInGrams
        case .stored(let product): return product.servingSizeInGrams
        }
    }

    private var quantity: Double {
        Double.parseUserInput(quantityText) ?? 0
    }

    private var preview: NutritionFacts {
        NutritionCalculator.nutrition(for: nutritionPer100g, quantityInGrams: quantity)
    }

    /// Quick quantities offered above the keyboard.
    private var shortcuts: [Double] {
        var values: [Double] = [50, 100, 150, 200]
        if let servingSize, !values.contains(servingSize) {
            values.insert(servingSize, at: 0)
        }
        return values
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.headline)
                    if let brand {
                        Text(brand)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Quantité") {
                HStack {
                    TextField("100", text: $quantityText)
                        .keyboardType(.decimalPad)
                        .frame(maxWidth: 120)
                    Text("grammes")
                        .foregroundStyle(.secondary)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(shortcuts, id: \.self) { value in
                            Button {
                                quantityText = QuantityFormatter.string(from: value)
                            } label: {
                                Text(shortcutLabel(for: value))
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            Section("Repas") {
                Picker("Repas", selection: $meal) {
                    ForEach(MealType.orderedCases) { meal in
                        Label(meal.localizedName, systemImage: meal.systemImageName).tag(meal)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }

            Section("Apports pour cette quantité") {
                NutritionBreakdownView(facts: preview)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(Color.alert)
                }
            }
        }
        .navigationTitle("Ajouter au journal")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Annuler") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Ajouter", action: log)
                    .disabled(quantity <= 0)
            }
        }
        .onAppear {
            meal = MealType.suggested(for: targetDate.isSameDay(as: .now) ? .now : targetDate)
            if let servingSize {
                quantityText = QuantityFormatter.string(from: servingSize)
            }
        }
    }

    private func shortcutLabel(for value: Double) -> String {
        if let servingSize, value == servingSize {
            return "1 portion (\(QuantityFormatter.grams(value)))"
        }
        return QuantityFormatter.grams(value)
    }

    private func log() {
        do {
            let product: FoodProduct
            switch source {
            case .stored(let stored):
                product = stored
            case .remote(let food):
                product = try ProductRepository(context: context).importProduct(from: food)
            }
            JournalService(context: context).log(
                product: product,
                quantityInGrams: quantity,
                meal: meal,
                on: targetDate
            )
            dismiss()
            onLogged()
        } catch {
            errorMessage = "L'aliment n'a pas pu être enregistré. Réessaie."
        }
    }
}

#Preview {
    NavigationStack {
        AddFoodSheet(food: PreviewData.sampleRemoteFoods[0])
    }
    .modelContainer(PreviewData.container())
}
