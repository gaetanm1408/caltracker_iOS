import SwiftData
import SwiftUI

struct RecipeListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\Recipe.name)]) private var recipes: [Recipe]

    @State private var isPresentingNewRecipe = false
    @State private var isPresentingGenerator = false
    @State private var searchText = ""

    private var filteredRecipes: [Recipe] {
        guard !searchText.isEmpty else { return recipes }
        return recipes.filter {
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
                    .searchable(text: $searchText, prompt: "Filtrer les recettes")
                }
            }
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
        }
    }

    private func delete(_ recipe: Recipe) {
        withAnimation {
            RecipeService(context: context).delete(recipe)
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

            HStack(spacing: 6) {
                Label("\(recipe.servings) portions", systemImage: "person.2")
                if recipe.preparationMinutes > 0 {
                    Text("·")
                    Label("\(recipe.preparationMinutes) min", systemImage: "clock")
                }
                Text("·")
                Text("\(recipe.ingredients.count) ingrédients")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .labelStyle(.titleAndIcon)

            if recipe.hasNutritionData {
                MacroSummaryLine(facts: recipe.nutritionPerServing)
                Text("par portion")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    RecipeListView()
        .modelContainer(PreviewData.container())
}
