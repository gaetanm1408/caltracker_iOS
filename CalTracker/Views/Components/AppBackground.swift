import SwiftUI

/// Fond de page commun à tous les onglets : la teinte de marque, très diluée,
/// se dissipant vers le fond système.
///
/// Le dégradé habille la page, jamais le contenu. Les cartes gardent leur
/// surface système, et ce n'est pas un détail de goût : les couleurs des macros
/// ont été choisies et validées contre cette surface-là. Les poser sur du vert
/// invaliderait les écarts calculés, daltonisme compris.
///
/// Les deux variantes se règlent contre le fond qu'elles remplacent, pas l'une
/// contre l'autre. La première tentative posait un vert à seize unités du gris
/// groupé d'iOS et, en mode sombre, un noir verdâtre sur du noir : invisible
/// dans les deux cas, et complètement invisible dans celui que l'app affichait.
struct AppBackground: View {
    var body: some View {
        LinearGradient(
            colors: [.surfaceTop, .surfaceBottom],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

extension View {
    /// Remplace le fond gris des listes par le dégradé de l'app.
    func appBackground() -> some View {
        scrollContentBackground(.hidden).background(AppBackground())
    }
}

#Preview {
    List {
        Section("Exemple") {
            Text("Une carte posée sur le dégradé")
            Text("Une autre")
        }
    }
    .listStyle(.insetGrouped)
    .appBackground()
}
