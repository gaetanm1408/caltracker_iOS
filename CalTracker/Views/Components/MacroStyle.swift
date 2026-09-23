import SwiftUI

extension Macro {
    /// Teinte de la macro, tirée du catalogue d'assets.
    ///
    /// Les trois couleurs sont les créneaux catégoriels 1, 2 et 3 d'une palette
    /// validée : ce sont les seuls trois qui séparent toutes leurs paires, en
    /// clair comme en sombre, y compris pour les trois formes de daltonisme.
    /// Les changer sans revalider casserait la lisibilité de la barre empilée.
    var tint: Color {
        switch self {
        case .proteins: return .macroProtein
        case .carbohydrates: return .macroCarb
        case .fats: return .macroFat
        }
    }
}

extension Color {
    static let macroProtein = Color("MacroProteinColor")
    static let macroCarb = Color("MacroCarbColor")
    static let macroFat = Color("MacroFatColor")
    /// Dépassement d'objectif. Couleur de statut, jamais réutilisée pour une
    /// macro : elle ne doit pas pouvoir se faire passer pour une série.
    static let alert = Color("AlertColor")
}

/// Jauge horizontale à bouts arrondis, posée sur sa piste.
private struct Meter: View {
    let progress: Double
    let tint: Color
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.08))
                if progress > 0 {
                    Capsule()
                        .fill(tint)
                        // Jamais plus étroit qu'un bout arrondi : une valeur
                        // minuscule doit rester visible plutôt que disparaître.
                        .frame(width: max(height, geometry.size.width * min(progress, 1)))
                }
            }
        }
        .frame(height: height)
    }
}

/// Ligne compacte « 420 kcal · P 24 g · G 40 g · L 12 g » des rangées de liste.
struct MacroSummaryLine: View {
    let facts: NutritionFacts
    var showsCalories: Bool = true

    var body: some View {
        HStack(spacing: 10) {
            if showsCalories {
                Text(QuantityFormatter.calories(facts.calories))
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
            }
            ForEach(Macro.allCases) { macro in
                HStack(spacing: 4) {
                    // L'identité passe par la pastille, pas par la couleur du
                    // texte : en petit corps, une teinte de série ne tient pas
                    // le contraste exigé d'un texte.
                    Circle()
                        .fill(macro.tint)
                        .frame(width: 6, height: 6)
                    Text("\(macro.shortName) \(QuantityFormatter.grams(macro.grams(in: facts)))")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .font(.caption)
        .monospacedDigit()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        let macros = Macro.allCases
            .map { "\($0.localizedName) \(QuantityFormatter.grams($0.grams(in: facts)))" }
            .joined(separator: ", ")
        return showsCalories ? "\(QuantityFormatter.calories(facts.calories)), \(macros)" : macros
    }
}

/// Jauge d'une macro face à son objectif du jour.
struct MacroProgressBar: View {
    let macro: Macro
    let consumed: Double
    let target: Double

    private var progress: Double {
        NutritionCalculator.progress(consumed: consumed, goal: target)
    }

    private var isOver: Bool { consumed > target && target > 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Circle()
                    .fill(macro.tint)
                    .frame(width: 7, height: 7)
                Text(macro.localizedName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 4)
                Text(QuantityFormatter.string(from: consumed))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(isOver ? Color.alert : .primary)
                Text("/ \(QuantityFormatter.grams(target))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .monospacedDigit()

            Meter(progress: progress, tint: isOver ? .alert : macro.tint)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(macro.localizedName) : \(QuantityFormatter.grams(consumed)) sur \(QuantityFormatter.grams(target))")
    }
}

/// Barre empilée : la part de calories que prend chaque macro dans la journée.
struct MacroDistributionBar: View {
    let facts: NutritionFacts

    private var distribution: [Macro: Double] {
        NutritionCalculator.macroDistribution(in: facts)
    }

    private var present: [Macro] {
        Macro.allCases.filter { (distribution[$0] ?? 0) > 0 }
    }

    private let gap: CGFloat = 2

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geometry in
                // Un filet de fond entre les segments : deux aplats qui se
                // touchent se lisent comme un seul.
                let gaps = gap * CGFloat(max(0, present.count - 1))
                let usable = max(0, geometry.size.width - gaps)
                HStack(spacing: gap) {
                    ForEach(present) { macro in
                        Capsule()
                            .fill(macro.tint)
                            .frame(width: usable * (distribution[macro] ?? 0))
                    }
                }
            }
            .frame(height: 10)

            HStack(spacing: 14) {
                ForEach(Macro.allCases) { macro in
                    HStack(spacing: 5) {
                        Circle()
                            .fill(macro.tint)
                            .frame(width: 7, height: 7)
                        Text("\(macro.localizedName) \(QuantityFormatter.percentage(distribution[macro] ?? 0))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Répartition des calories : " + Macro.allCases
            .map { "\($0.localizedName) \(QuantityFormatter.percentage(distribution[$0] ?? 0))" }
            .joined(separator: ", "))
    }
}

/// Anneau des calories, en tête du journal.
///
/// Volontairement à l'encre et non à la couleur d'accent : les trois macros
/// occupent déjà le champ chromatique de la carte, et un quatrième ton vert
/// s'y confondrait avec celui des lipides.
struct CalorieRing: View {
    let consumed: Double
    let goal: Double
    var lineWidth: CGFloat = 13

    private var progress: Double {
        NutritionCalculator.progress(consumed: consumed, goal: goal)
    }

    private var isOver: Bool { consumed > goal && goal > 0 }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.08), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    isOver ? Color.alert : Color.primary.opacity(0.85),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.35), value: progress)

            VStack(spacing: 0) {
                Text("\(Int(consumed.rounded()))")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(isOver ? Color.alert : .primary)
                Text("/ \(Int(goal.rounded()))")
                    .font(.system(.caption2, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Text("kcal")
                    .font(.system(size: 9, weight: .medium))
                    .textCase(.uppercase)
                    .kerning(0.6)
                    .foregroundStyle(.tertiary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Int(consumed.rounded())) calories sur \(Int(goal.rounded()))")
    }
}
