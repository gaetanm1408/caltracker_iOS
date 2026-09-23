import Foundation
import HealthKit

/// Source des dépenses énergétiques de la journée.
///
/// Abstraite pour deux raisons : l'app doit rester utilisable là où HealthKit
/// n'existe pas ou n'est pas autorisé, et les aperçus comme les tests ont
/// besoin d'une source déterministe.
protocol ActivityEnergySource: Sendable {
    var isAvailable: Bool { get }

    /// Ouvre la demande d'autorisation. Renvoie `false` si elle n'a pas pu
    /// être présentée — jamais si l'utilisateur a refusé, qu'Apple ne révèle
    /// pas pour les autorisations de lecture.
    func requestAuthorization() async -> Bool

    /// Calories actives dépensées ce jour-là, ou `nil` quand la donnée n'est
    /// pas lisible. Zéro signifie une journée sans activité enregistrée.
    func activeEnergyBurned(on date: Date) async -> Double?
}

/// Lit les dépenses écrites dans Apple Santé.
///
/// Garmin Connect, comme la plupart des applications de sport, y dépose ses
/// séances : passer par Santé évite toute dépendance à un service tiers.
///
/// `@unchecked Sendable` : `HKHealthStore` n'est pas marqué `Sendable` mais sa
/// documentation garantit qu'une même instance accepte des requêtes depuis
/// n'importe quel fil, et les autres membres sont immuables.
final class HealthKitActivitySource: ActivityEnergySource, @unchecked Sendable {
    private let store = HKHealthStore()
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    private var energyType: HKQuantityType? {
        HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)
    }

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization() async -> Bool {
        guard isAvailable, let energyType else { return false }
        do {
            // Lecture seule : l'app ne réécrit rien dans Santé.
            try await store.requestAuthorization(toShare: [], read: [energyType])
            return true
        } catch {
            return false
        }
    }

    func activeEnergyBurned(on date: Date) async -> Double? {
        guard isAvailable, let energyType else { return nil }

        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: energyType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, _ in
                // Une autorisation refusée ne remonte pas d'erreur : elle se
                // traduit par une absence d'échantillon, donc par nil.
                continuation.resume(
                    returning: statistics?.sumQuantity()?.doubleValue(for: .kilocalorie())
                )
            }
            store.execute(query)
        }
    }
}

/// Source fixe, pour les aperçus et les tests.
struct StubActivityEnergySource: ActivityEnergySource {
    var isAvailable: Bool = true
    var authorizationSucceeds: Bool = true
    var energyByDay: [Date: Double] = [:]
    var defaultEnergy: Double?

    func requestAuthorization() async -> Bool { authorizationSucceeds }

    func activeEnergyBurned(on date: Date) async -> Double? {
        let day = Calendar.current.startOfDay(for: date)
        return energyByDay[day] ?? defaultEnergy
    }
}
