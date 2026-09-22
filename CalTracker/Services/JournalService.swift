import Foundation
import SwiftData

/// Read and write operations on the daily food journal.
struct JournalService {
    let context: ModelContext
    private let calendar: Calendar

    init(context: ModelContext, calendar: Calendar = .current) {
        self.context = context
        self.calendar = calendar
    }

    func entries(for date: Date) throws -> [FoodEntry] {
        let day = calendar.startOfDay(for: date)
        let descriptor = FetchDescriptor<FoodEntry>(
            predicate: #Predicate { $0.day == day },
            sortBy: [SortDescriptor(\.consumedAt)]
        )
        return try context.fetch(descriptor)
    }

    func summary(for date: Date, goals: NutritionGoals) throws -> DailyNutritionSummary {
        DailyNutritionSummary.make(
            date: calendar.startOfDay(for: date),
            entries: try entries(for: date),
            goals: goals
        )
    }

    @discardableResult
    func log(
        product: FoodProduct,
        quantityInGrams: Double,
        meal: MealType,
        on date: Date = .now
    ) -> FoodEntry {
        let entry = FoodEntry(
            product: product,
            quantityInGrams: quantityInGrams,
            meal: meal,
            consumedAt: consumptionDate(for: date),
            calendar: calendar
        )
        product.lastUsedAt = .now
        context.insert(entry)
        return entry
    }

    /// Logs one or more servings of a recipe as a single journal line.
    @discardableResult
    func log(
        recipe: Recipe,
        servings: Double,
        meal: MealType,
        on date: Date = .now
    ) -> FoodEntry? {
        guard recipe.hasNutritionData, servings > 0 else { return nil }

        let perServing = recipe.nutritionPerServing
        let totalGrams = recipe.ingredients.compactMap(\.quantityInGrams).reduce(0, +)
        let gramsPerServing = totalGrams / Double(max(1, recipe.servings))
        let loggedGrams = max(gramsPerServing * servings, 1)

        // Re-express the serving's nutrition per 100 g so the entry behaves
        // like any other line when its quantity is edited later.
        let per100g = perServing.scaled(by: 100 / max(gramsPerServing, 1))

        let entry = FoodEntry(
            product: nil,
            productNameSnapshot: recipe.name,
            brandSnapshot: "Recette",
            nutritionPer100g: per100g,
            quantityInGrams: loggedGrams,
            meal: meal,
            consumedAt: consumptionDate(for: date),
            calendar: calendar
        )
        context.insert(entry)
        return entry
    }

    func update(_ entry: FoodEntry, quantityInGrams: Double, meal: MealType) {
        entry.quantityInGrams = max(0, quantityInGrams)
        entry.meal = meal
    }

    func delete(_ entry: FoodEntry) {
        context.delete(entry)
    }

    func move(_ entry: FoodEntry, to date: Date) {
        entry.move(to: consumptionDate(for: date), calendar: calendar)
    }

    /// Keeps the current time of day when logging on a past date, so entries
    /// stay ordered inside their meal.
    private func consumptionDate(for date: Date) -> Date {
        if calendar.isDateInToday(date) { return date }
        let now = Date.now
        let time = calendar.dateComponents([.hour, .minute, .second], from: now)
        return calendar.date(
            bySettingHour: time.hour ?? 12,
            minute: time.minute ?? 0,
            second: time.second ?? 0,
            of: date
        ) ?? date
    }
}
