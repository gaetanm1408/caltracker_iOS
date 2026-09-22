import SwiftData
import SwiftUI

struct JournalView: View {
    @Query private var profiles: [UserProfile]

    @State private var selectedDate: Date = Date.now.startOfDay()
    @State private var isPresentingSearch = false
    @State private var isPresentingGoals = false

    private var goals: NutritionGoals {
        profiles.first?.goals ?? .default
    }

    var body: some View {
        NavigationStack {
            JournalDayView(day: selectedDate, goals: goals)
                .navigationTitle(selectedDate.journalTitle())
                .navigationBarTitleDisplayMode(.inline)
                .safeAreaInset(edge: .top) {
                    DayNavigationBar(selectedDate: $selectedDate)
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            isPresentingGoals = true
                        } label: {
                            Label("Objectifs", systemImage: "target")
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            isPresentingSearch = true
                        } label: {
                            Label("Ajouter un aliment", systemImage: "plus")
                        }
                    }
                }
                .sheet(isPresented: $isPresentingSearch) {
                    NavigationStack {
                        FoodSearchView(targetDate: selectedDate, isEmbeddedInSheet: true)
                    }
                }
                .sheet(isPresented: $isPresentingGoals) {
                    NavigationStack {
                        GoalsView()
                    }
                    .presentationDetents([.medium, .large])
                }
        }
    }
}

/// Day-by-day navigation strip sitting above the journal.
private struct DayNavigationBar: View {
    @Binding var selectedDate: Date

    private var canGoForward: Bool {
        !Calendar.current.isDateInToday(selectedDate) && selectedDate < Date.now
    }

    var body: some View {
        HStack {
            Button {
                withAnimation { selectedDate = selectedDate.addingDays(-1) }
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Jour précédent")

            Spacer()

            DatePicker(
                "Date",
                selection: $selectedDate,
                in: ...Date.now,
                displayedComponents: .date
            )
            .labelsHidden()
            .datePickerStyle(.compact)

            Spacer()

            Button {
                withAnimation { selectedDate = selectedDate.addingDays(1) }
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 44, height: 44)
            }
            .disabled(!canGoForward)
            .accessibilityLabel("Jour suivant")
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .background(.bar)
    }
}

/// Entries and totals for a single day. Split out so `@Query` can be rebuilt
/// with the selected day as its predicate.
private struct JournalDayView: View {
    let day: Date
    let goals: NutritionGoals

    @Environment(\.modelContext) private var context
    @Query private var entries: [FoodEntry]
    @State private var entryBeingEdited: FoodEntry?

    init(day: Date, goals: NutritionGoals) {
        self.day = day
        self.goals = goals
        let startOfDay = day.startOfDay()
        _entries = Query(
            filter: #Predicate<FoodEntry> { $0.day == startOfDay },
            sort: [SortDescriptor(\FoodEntry.consumedAt)]
        )
    }

    private var summary: DailyNutritionSummary {
        DailyNutritionSummary.make(date: day, entries: entries, goals: goals)
    }

    var body: some View {
        List {
            Section {
                DailySummaryCard(summary: summary)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            if entries.isEmpty {
                Section {
                    ContentUnavailableView(
                        "Journée vide",
                        systemImage: "fork.knife.circle",
                        description: Text("Ajoute un aliment avec le bouton + pour commencer à suivre tes macros.")
                    )
                }
            } else {
                ForEach(MealType.orderedCases) { meal in
                    let mealEntries = entries.filter { $0.meal == meal }
                    if !mealEntries.isEmpty {
                        MealSection(
                            meal: meal,
                            entries: mealEntries,
                            onEdit: { entryBeingEdited = $0 },
                            onDelete: delete
                        )
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .sheet(item: $entryBeingEdited) { entry in
            NavigationStack {
                EditEntrySheet(entry: entry)
            }
            .presentationDetents([.medium])
        }
    }

    private func delete(_ entry: FoodEntry) {
        withAnimation {
            JournalService(context: context).delete(entry)
        }
    }
}

private struct MealSection: View {
    let meal: MealType
    let entries: [FoodEntry]
    let onEdit: (FoodEntry) -> Void
    let onDelete: (FoodEntry) -> Void

    private var mealNutrition: NutritionFacts {
        NutritionCalculator.total(of: entries)
    }

    var body: some View {
        Section {
            ForEach(entries) { entry in
                Button {
                    onEdit(entry)
                } label: {
                    FoodEntryRow(entry: entry)
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        onDelete(entry)
                    } label: {
                        Label("Supprimer", systemImage: "trash")
                    }
                }
            }
        } header: {
            HStack {
                Label(meal.localizedName, systemImage: meal.systemImageName)
                Spacer()
                Text(QuantityFormatter.calories(mealNutrition.calories))
                    .monospacedDigit()
            }
            .font(.subheadline)
            .textCase(nil)
        }
    }
}

#Preview {
    JournalView()
        .modelContainer(PreviewData.container())
}
