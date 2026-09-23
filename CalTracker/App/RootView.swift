import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    @AppStorage("installedRecipeCatalogueVersion") private var catalogueVersion = 0

    var body: some View {
        TabView {
            Tab("Journal", systemImage: "list.bullet.clipboard") {
                JournalView()
            }
            Tab("Recherche", systemImage: "magnifyingglass") {
                NavigationStack {
                    FoodSearchView()
                }
            }
            Tab("Recettes", systemImage: "fork.knife") {
                RecipeListView()
            }
            Tab("Courses", systemImage: "cart") {
                ShoppingListView()
            }
            Tab("Réglages", systemImage: "gearshape") {
                SettingsView()
            }
        }
        .task {
            ensureProfileExists()
            installRecipeCatalogue()
        }
    }

    /// The app always needs one profile row to hold the daily goals.
    private func ensureProfileExists() {
        guard profiles.isEmpty else { return }
        context.insert(UserProfile())
    }

    private func installRecipeCatalogue() {
        do {
            catalogueVersion = try RecipeCatalogueSeeder(context: context)
                .seedIfNeeded(installedVersion: catalogueVersion)
        } catch {
            // Les recettes livrées sont un confort de démarrage : si la
            // ressource manque ou change de forme, l'app reste utilisable.
        }
    }
}

#Preview {
    RootView()
        .modelContainer(PreviewData.container())
}
