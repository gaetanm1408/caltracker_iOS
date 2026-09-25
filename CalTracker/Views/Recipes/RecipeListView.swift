import SwiftData
import SwiftUI

struct RecipeListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\Recipe.name)]) private var recipes: [Recipe]

    @State private var isPresentingNewRecipe = false
    @State private var isPresentingGenerator = false
    @State private var isPresentingFilters = false
    @State private var criteria = RecipeCriteria.unrestricted
    @State private var searchText = ""

    private var filteredRecipes: [Recipe] {
        let matching = RecipeFilter.eligible(recipes, matching: criteria)
        guard !searchText.isEmpty else { return matching }
        return matching.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
                || $0.ingredients.contains { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if recipes.isEmpty {
                    ContentUnavailableView {
                        Label("Aucune recette", systemImage: "fork.knife")
                    } description: {
                        Text("Crée une recette pour calculer ses macros et générer ta liste de courses.")
                    } actions: {
                        Button("Nouvelle recette") { isPresentingNewRecipe = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else if filteredRecipes.isEmpty {
                    ContentUnavailableView {
                        Label("Aucune recette ne passe tes critères", systemImage: "line.3.horizontal.decrease.circle")
                    } description: {
                        Text("Assouplis les filtres, ou change ta recherche.")
                    } actions: {
                        Button("Réinitialiser les filtres") { criteria = .unrestricted }
                            .buttonStyle(.borderedProminent)
                            .disabled(criteria.isUnrestricted)
                    }
                } else {
                    List {
                        ForEach(filteredRecipes) { recipe in
                            NavigationLink(value: recipe) {
                                RecipeRow(recipe: recipe)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    delete(recipe)
                                } label: {
                                    Label("Supprimer", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    RecipeService(context: context).toggleFavorite(recipe)
                                } label: {
                                    Label("Favori", systemImage: recipe.isFavorite ? "star.slash" : "star")
                                }
                                .tint(.yellow)
                            }
                        }
                    }
                }
            }
            .appBackground()
            .searchable(text: $searchText, prompt: "Chercher une recette")
            .safeAreaInset(edge: .top) { activeCriteriaBar }
            .navigationTitle("Recettes")
            .navigationDestination(for: Recipe.self) { recipe in
                RecipeDetailView(recipe: recipe)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isPresentingGenerator = true
                    } label: {
                        Label("Générer la liste", systemImage: "cart.badge.plus")
                    }
                    .disabled(recipes.isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPresentingFilters = true
                    } label: {
                        Label(
                            "Filtrer",
                            systemImage: criteria.isUnrestricted
                                ? "line.3.horizontal.decrease.circle"
                                : "line.3.horizontal.decrease.circle.fill"
                        )
                    }
                    .labelStyle(.titleAndIcon)
                    .disabled(recipes.isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPresentingNewRecipe = true
                    } label: {
                        Label("Nouvelle recette", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $isPresentingNewRecipe) {
                NavigationStack {
                    RecipeFormView()
                }
            }
            .sheet(isPresented: $isPresentingGenerator) {
                NavigationStack {
                    ShoppingListGeneratorView(recipes: recipes)
                }
            }
            .sheet(isPresented: $isPresentingFilters) {
                NavigationStack {
                    RecipeFilterSheet(
                        criteria: $criteria,
                        ingredientGroups: RecipeFilter.groupedSelectableIngredients(in: recipes),
                        matchCount: RecipeFilter.eligible(recipes, matching: criteria).count
                    )
                }
                .presentationDetents([.large])
            }
        }
    }

    /// Rappel permanent qu'un filtre est posé : sans lui, une liste écourtée
    /// passe pour une recette disparue.
    @ViewBuilder
    private var activeCriteriaBar: some View {
        if criteria.activeCount > 0 {
            HStack(spacing: 8) {
                Image(systemName: "line.3.horizontal.decrease.circle.fill")
                    .foregroundStyle(.tint)
                Text(criteria.summaryComponents.joined(separator: " · "))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 8)
                Button("Effacer") { criteria = .unrestricted }
            }
            .font(.footnote)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.bar)
            .overlay(alignment: .bottom) { Divider() }
        }
    }

    private func delete(_ recipe: Recipe) {
        withAnimation {
            RecipeService(context: context).delete(recipe)
        }
    }
}

/// Les critères de sélection, présentés en feuille depuis la liste.
private struct RecipeFilterSheet: View {
    @Binding var criteria: RecipeCriteria
    let ingredientGroups: [IngredientGroup]
    let matchCount: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            RecipeCriteriaSections(
                criteria: $criteria,
                ingredientGroups: ingredientGroups,
                showsCategoryPicker: true,
                matchSummary: "\(matchCount) recette(s) passent tes critères."
            )
        }
        .navigationTitle("Filtrer les recettes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Réinitialiser") { criteria = .unrestricted }
                    .disabled(criteria.isUnrestricted)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Terminé") { dismiss() }
            }
        }
    }
}

private struct RecipeRow: View {
    let recipe: Recipe

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(recipe.name)
                    .font(.body)
                if recipe.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                }
            }

            // Les mots « portions » et « ingrédients » ne disent rien que
            // l'icône ne dise déjà, et ils faisaient couper la ligne en deux :
            // « por-tions », « Colla-tion ». Les chiffres suffisent, le
            // libellé complet reste pour VoiceOver.
            HStack(spacing: 12) {
                Label(recipe.category.localizedName, systemImage: recipe.category.systemImageName)
                Label("\(recipe.servings)", systemImage: "person.2")
                if recipe.preparationMinutes > 0 {
                    Label("\(recipe.preparationMinutes) min", systemImage: "clock")
                }
                Label("\(recipe.ingredients.count)", systemImage: "carrot")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .labelStyle(.titleAndIcon)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(metadataDescription)

            if recipe.hasNutritionData {
                MacroSummaryLine(facts: recipe.nutritionPerServing)
                Text("par portion")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }

    private var metadataDescription: String {
        var parts = [
            recipe.category.localizedName,
            "\(recipe.servings) portions"
        ]
        if recipe.preparationMinutes > 0 {
            parts.append("\(recipe.preparationMinutes) minutes")
        }
        parts.append("\(recipe.ingredients.count) ingrédients")
        return parts.joined(separator: ", ")
    }
}

#Preview {
    RecipeListView()
        .modelContainer(PreviewData.container())
}
