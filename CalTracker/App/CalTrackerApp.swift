import SwiftData
import SwiftUI

@main
struct CalTrackerApp: App {
    private let container: ModelContainer
    private let foodClient: FoodDatabaseClient
    private let activitySource: ActivityEnergySource = HealthKitActivitySource()

    init() {
        do {
            container = try ModelContainer(for: AppSchema.schema)
        } catch {
            fatalError("Impossible de créer le stockage SwiftData : \(error)")
        }
        foodClient = OpenFoodFactsClient()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.foodDatabaseClient, foodClient)
                .environment(\.activityEnergySource, activitySource)
        }
        .modelContainer(container)
    }
}

/// Single place listing the persisted models, shared by the app and the tests.
enum AppSchema {
    static let models: [any PersistentModel.Type] = [
        FoodProduct.self,
        FoodEntry.self,
        Recipe.self,
        RecipeIngredient.self,
        ShoppingListItem.self,
        UserProfile.self
    ]

    static var schema: Schema { Schema(models) }

    /// In-memory container for previews and tests.
    static func inMemoryContainer() throws -> ModelContainer {
        try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }
}

private struct FoodDatabaseClientKey: EnvironmentKey {
    static let defaultValue: FoodDatabaseClient = OpenFoodFactsClient()
}

private struct ActivityEnergySourceKey: EnvironmentKey {
    static let defaultValue: ActivityEnergySource = HealthKitActivitySource()
}

extension EnvironmentValues {
    var foodDatabaseClient: FoodDatabaseClient {
        get { self[FoodDatabaseClientKey.self] }
        set { self[FoodDatabaseClientKey.self] = newValue }
    }

    var activityEnergySource: ActivityEnergySource {
        get { self[ActivityEnergySourceKey.self] }
        set { self[ActivityEnergySourceKey.self] = newValue }
    }
}
