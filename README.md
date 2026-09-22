# CalTracker

Application iOS de suivi calorique en SwiftUI : recherche de produits dans
Open Food Facts, journal alimentaire quotidien persisté avec SwiftData, calcul
des macros (protéines / glucides / lipides) et module de recettes capable de
générer automatiquement une liste de courses.

## Prérequis

- Xcode 16 ou plus récent
- iOS 18.0 minimum (SwiftData, `#Index`, `TabView` avec `Tab`)
- Swift 6

## Démarrer

```bash
open CalTracker.xcodeproj
```

Puis lancer le schéma `CalTracker`. Aucune dépendance externe : l'app n'utilise
que les frameworks Apple et l'API publique d'Open Food Facts.

Les tests s'exécutent avec le framework Swift Testing :

```bash
xcodebuild test -scheme CalTracker -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Fonctionnalités

- **Recherche de produits** — interrogation d'Open Food Facts avec anti-rebond,
  annulation des requêtes obsolètes et repli sur les produits déjà utilisés.
- **Scanner de code-barres** — lecture EAN-13 / EAN-8 / UPC-E via VisionKit, qui
  enchaîne directement sur la fiche du produit trouvé. L'écran gère le refus
  d'accès à la caméra et les appareils sans scanner (Simulateur).
- **Journal quotidien** — saisie par repas (petit-déjeuner, déjeuner, dîner,
  collation), navigation jour par jour, modification et suppression des lignes.
- **Macros** — anneau de calories, barres de progression par macro face aux
  objectifs, répartition en pourcentage de l'apport énergétique, objectifs
  quotidiens paramétrables.
- **Recettes** — ingrédients saisis à la main ou importés d'Open Food Facts
  (avec leurs macros), calcul des apports par portion, duplication, ajout d'une
  recette au journal.
- **Liste de courses** — génération à partir des recettes sélectionnées, mise à
  l'échelle selon le nombre de portions souhaité, fusion des ingrédients
  identiques, exclusion optionnelle des produits de placard, partage en texte.

## Architecture

Les trois couches sont séparées et ne se connaissent que dans un sens :
l'interface dépend de la logique métier, qui dépend des modèles.

```
CalTracker/
├── App/            Point d'entrée, schéma SwiftData, injection de dépendances
├── Models/         Modèles de données (SwiftData) et types valeur
├── Networking/     Client Open Food Facts et formats de transport (DTO)
├── Services/       Logique métier (calculs, persistance, agrégation)
├── ViewModels/     État des écrans à logique asynchrone
├── Views/          Interface SwiftUI, découpée par module
└── Utilities/      Formatage, extensions, données de prévisualisation
```

### Modèles (`Models/`)

Les entités persistées — `FoodProduct`, `FoodEntry`, `Recipe`,
`RecipeIngredient`, `ShoppingListItem`, `UserProfile` — ne contiennent aucun
calcul : elles exposent leurs données et délèguent l'arithmétique aux services.
Les types valeur `NutritionFacts`, `Macro`, `MealType`, `MeasurementUnit` et
`NutritionGoals` sont indépendants de SwiftData, donc testables isolément.

Deux choix structurants :

- **Les apports sont figés à l'enregistrement.** Une ligne de journal copie les
  valeurs pour 100 g du produit au moment de la saisie. Corriger ou supprimer
  une fiche produit ne réécrit donc jamais l'historique.
- **Le jour est stocké à part.** `FoodEntry.day` contient le début de journée,
  ce qui permet au journal de récupérer une date par égalité plutôt que par
  parcours d'intervalle.

### Logique métier (`Services/`)

- `NutritionCalculator` — mise à l'échelle, totaux, répartition des macros et
  progression vers les objectifs. Entièrement pur, sans SwiftData ni SwiftUI.
- `ShoppingListBuilder` — fusion des ingrédients. Deux lignes ne sont
  regroupées que si leurs noms coïncident après normalisation (accents, casse,
  pluriel) **et** si leurs unités partagent une dimension : 200 g de tomates et
  3 tomates restent séparés puisqu'ils ne s'additionnent pas.
- `JournalService`, `RecipeService`, `ShoppingListService`, `ProductRepository`
  — opérations de lecture et d'écriture sur le `ModelContext`.

### Réseau (`Networking/`)

`OpenFoodFactsClient` implémente le protocole `FoodDatabaseClient`, ce qui
permet de substituer `StubFoodDatabaseClient` dans les tests et les aperçus.
Les DTO absorbent les irrégularités d'une base collaborative : un même champ
peut arriver en nombre ou en texte (`FlexibleNumber`), l'énergie peut être
absente (recalculée depuis les macros) ou exprimée en kilojoules (convertie),
et les fiches trop incomplètes sont écartées avant d'atteindre l'interface.

## Tests

- `NutritionCalculatorTests` — mise à l'échelle, totaux, répartition, objectifs
- `ShoppingListBuilderTests` — fusion, conversion d'unités, normalisation des
  noms, mise à l'échelle par portions, produits de placard
- `OpenFoodFactsMappingTests` — décodage tolérant, conversion kJ → kcal, rejet
  des fiches inexploitables
- `FoodSearchViewModelTests` — recherche et résolution d'un code-barres scanné
- `JournalServiceTests` — journal sur conteneur SwiftData en mémoire
- `ShoppingListServiceTests` / `RecipeServiceTests` — persistance et calculs de
  recettes

## Crédits

Les données produits proviennent d'[Open Food Facts](https://world.openfoodfacts.org),
base collaborative sous licence ODbL.
