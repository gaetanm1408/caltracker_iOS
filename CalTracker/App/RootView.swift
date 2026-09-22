import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]

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
        }
        .task {
            ensureProfileExists()
        }
    }

    /// The app always needs one profile row to hold the daily goals.
    private func ensureProfileExists() {
        guard profiles.isEmpty else { return }
        context.insert(UserProfile())
    }
}

#Preview {
    RootView()
        .modelContainer(PreviewData.container())
}
