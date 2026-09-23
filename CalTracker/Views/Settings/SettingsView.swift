import SwiftData
import SwiftUI

/// Profil, objectifs, état des intégrations et informations sur l'app.
struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.activityEnergySource) private var activitySource
    @Query private var profiles: [UserProfile]
    @Query(sort: [SortDescriptor(\Recipe.name)]) private var recipes: [Recipe]
    @AppStorage("installedRecipeCatalogueVersion") private var catalogueVersion = 0

    @State private var catalogueMessage: String?

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            List {
                profileSection
                healthSection
                catalogueSection
                aboutSection
            }
            .navigationTitle("Réglages")
        }
    }

    private var profileSection: some View {
        Section {
            NavigationLink {
                GoalsView()
            } label: {
                Label("Profil et objectifs", systemImage: "target")
            }
        } header: {
            Text("Mes objectifs")
        } footer: {
            if let profile {
                Text(profileSummary(profile))
            }
        }
    }

    private func profileSummary(_ profile: UserProfile) -> String {
        guard profile.usesCalculatedGoal, profile.canCalculateGoal else {
            return "Objectif saisi à la main : \(QuantityFormatter.calories(profile.goals.calories)) par jour."
        }
        return """
        \(profile.weightGoal.localizedName) · \(profile.activityLevel.localizedName)
        Dépense estimée \(QuantityFormatter.calories(profile.totalDailyEnergyExpenditure)), \
        cible \(QuantityFormatter.calories(profile.goals.calories)).
        """
    }

    private var healthSection: some View {
        Section {
            LabeledContent {
                Text(activitySource.isAvailable ? "Actif" : "Indisponible")
                    .foregroundStyle(activitySource.isAvailable ? .green : .secondary)
            } label: {
                Label("Apple Santé", systemImage: "heart")
            }
        } header: {
            Text("Dépenses énergétiques")
        } footer: {
            if activitySource.isAvailable {
                Text("Les calories brûlées enregistrées par ta montre s'affichent à côté de ton objectif, sans le modifier.")
            } else {
                Text("La lecture d'Apple Santé exige un entitlement HealthKit, que seul un compte développeur Apple payant accorde. Le code est en place et se réactivera tout seul le jour venu.")
            }
        }
    }

    private var catalogueSection: some View {
        Section {
            LabeledContent("Recettes", value: "\(recipes.count)")
            Button {
                reinstallCatalogue()
            } label: {
                Label("Réinstaller les recettes livrées", systemImage: "arrow.clockwise")
            }
        } header: {
            Text("Recettes")
        } footer: {
            Text(catalogueMessage ?? "Remet les recettes d'origine que tu aurais supprimées. Celles que tu as créées ou modifiées ne sont pas touchées.")
        }
    }

    private var aboutSection: some View {
        Section {
            LabeledContent("Version", value: Self.appVersion)
            Link(destination: URL(string: "https://world.openfoodfacts.org")!) {
                Label("Open Food Facts", systemImage: "arrow.up.right.square")
            }
        } header: {
            Text("À propos")
        } footer: {
            Text("Les informations produits proviennent d'Open Food Facts, base de données collaborative sous licence ODbL. Les valeurs des recettes livrées sont des tables de référence, pas les produits que tu achètes.")
        }
    }

    private static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }

    private func reinstallCatalogue() {
        do {
            // Repartir de zéro force le réexamen de toutes les recettes ; celles
            // déjà présentes sont reconnues par leur nom et laissées en place.
            catalogueVersion = try RecipeCatalogueSeeder(context: context)
                .seedIfNeeded(installedVersion: 0)
            catalogueMessage = "Recettes livrées réinstallées."
        } catch {
            catalogueMessage = "Les recettes livrées n'ont pas pu être relues."
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(PreviewData.container())
}
