import SwiftUI

/// Fond de page commun à tous les onglets : la teinte de marque, très diluée,
/// se dissipant vers le fond système.
///
/// Le dégradé habille la page, jamais le contenu. Les cartes gardent leur
/// surface quasi blanche, et ce n'est pas un détail de goût : les couleurs des
/// macros ont été choisies et validées contre cette surface-là. Les poser sur
/// du vert invaliderait les écarts calculés, daltonisme compris.
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
