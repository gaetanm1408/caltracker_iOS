import SwiftUI

/// Les critères de sélection d'une recette, sous forme de sections de `Form`.
///
/// Partagées entre l'assistant menus, qui s'en sert pour composer un planning,
/// et la liste de recettes, qui s'en sert pour parcourir le catalogue. Un seul
/// endroit à corriger, et deux écrans qui ne peuvent pas diverger.
struct RecipeCriteriaSections: View {
    @Binding var criteria: RecipeCriteria
    let ingredientGroups: [IngredientGroup]
    /// Le planning tire repas et collations dans des viviers séparés : le choix
    /// du type ne lui sert à rien.
    var showsCategoryPicker = false
    /// Ce qui passe les critères, affiché sous le choix des aliments.
    var matchSummary: String?

    var body: some View {
        if showsCategoryPicker {
            Section {
                Picker("Type", selection: categoryScope) {
                    ForEach(CategoryScope.allCases) { scope in
                        Text(scope.localizedName).tag(scope)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
        }

        Section {
            Picker("Calories", selection: $criteria.calorieBand) {
                ForEach(CalorieBand.allCases) { band in
                    if let detail = band.detail {
                        Text("\(band.localizedName) — \(detail)").tag(band)
                    } else {
                        Text(band.localizedName).tag(band)
                    }
                }
            }
            Picker("Protéines", selection: $criteria.proteinFloor) {
                ForEach(ProteinFloor.allCases) { floor in
                    Text(floor.localizedName).tag(floor)
                }
            }
        } header: {
            Text("Ce que je veux dans l'assiette")
        } footer: {
            Text("Ces deux bornes ne jugent que les repas : une collation tourne autour de 250 kcal.")
        }

        Section {
            ForEach(CookingEquipment.allCases.filter { !$0.isAlwaysAvailable }) { equipment in
                Toggle(isOn: equipmentBinding(equipment)) {
                    Label(equipment.localizedName, systemImage: equipment.systemImageName)
                }
            }
        } header: {
            Text("Mon matériel")
        } footer: {
            Text("Les recettes sans cuisson restent proposées quoi qu'il arrive.")
        }

        Section {
            NavigationLink {
                ExcludedIngredientsView(
                    groups: ingredientGroups,
                    excluded: $criteria.excludedIngredients
                )
            } label: {
                LabeledContent("Aliments que je ne veux pas") {
                    Text(excludedSummary).foregroundStyle(.secondary)
                }
            }
        } footer: {
            if let matchSummary {
                Text(matchSummary)
            }
        }
    }

    private var excludedSummary: String {
        let count = criteria.excludedIngredients.count
        return count == 0 ? "Aucun" : "\(count) écarté(s)"
    }

    private func equipmentBinding(_ equipment: CookingEquipment) -> Binding<Bool> {
        Binding(
            get: { criteria.availableEquipment.contains(equipment) },
            set: { isOn in
                if isOn {
                    criteria.availableEquipment.insert(equipment)
                } else {
                    criteria.availableEquipment.remove(equipment)
                }
            }
        )
    }

    private var categoryScope: Binding<CategoryScope> {
        Binding(
            get: { CategoryScope(criteria.categories) },
            set: { criteria.categories = $0.categories }
        )
    }
}

/// Raccourci de saisie pour l'ensemble des types retenus : les trois seules
/// combinaisons qui ont un sens à l'écran.
enum CategoryScope: String, CaseIterable, Identifiable {
    case all
    case meals
    case snacks

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .all: return "Tout"
        case .meals: return "Repas"
        case .snacks: return "Collations"
        }
    }

    var categories: Set<RecipeCategory> {
        switch self {
        case .all: return Set(RecipeCategory.allCases)
        case .meals: return [.meal]
        case .snacks: return [.snack]
        }
    }

    init(_ categories: Set<RecipeCategory>) {
        if categories == [.meal] {
            self = .meals
        } else if categories == [.snack] {
            self = .snacks
        } else {
            self = .all
        }
    }
}

/// Choix des aliments à ne pas voir proposer, rangés par famille.
struct ExcludedIngredientsView: View {
    let groups: [IngredientGroup]
    @Binding var excluded: Set<String>

    @State private var search = ""

    /// Les familles où il reste quelque chose à montrer après la recherche.
    private var visibleGroups: [IngredientGroup] {
        guard !search.isEmpty else { return groups }
        return groups.compactMap { group in
            let names = group.names.filter { $0.localizedCaseInsensitiveContains(search) }
            return names.isEmpty ? nil : IngredientGroup(family: group.family, names: names)
        }
    }

    var body: some View {
        List {
            if groups.isEmpty {
                ContentUnavailableView(
                    "Aucun ingrédient",
                    systemImage: "carrot",
                    description: Text("Les aliments proposés ici viennent de tes recettes.")
                )
            } else if visibleGroups.isEmpty {
                ContentUnavailableView.search(text: search)
            } else {
                ForEach(visibleGroups) { group in
                    Section {
                        ForEach(group.names, id: \.self) { ingredient in
                            row(for: ingredient)
                        }
                    } header: {
                        Label(group.family.localizedName, systemImage: group.family.systemImageName)
                    }
                }
            }
        }
        .searchable(text: $search, prompt: "Chercher un aliment")
        .navigationTitle("Aliments écartés")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !excluded.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Réinitialiser") { excluded.removeAll() }
                }
            }
        }
    }

    private func row(for ingredient: String) -> some View {
        let key = ShoppingListBuilder.normalize(ingredient)
        let isExcluded = excluded.contains(key)
        return Button {
            if isExcluded {
                excluded.remove(key)
            } else {
                excluded.insert(key)
            }
        } label: {
            HStack {
                Text(ingredient)
                    .foregroundStyle(isExcluded ? .secondary : .primary)
                    .strikethrough(isExcluded)
                Spacer()
                if isExcluded {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
