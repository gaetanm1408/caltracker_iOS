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

## Installation sans Mac

La CI (`.github/workflows/ci.yml`) compile, teste et produit à chaque push un
`.ipa` **non signé**, déposé en artefact sous un nom qui porte sa version, son
numéro de build et son commit : `CalTracker-1.0-b26-0e65659`.

Le numéro de build est celui de l'exécution qui l'a produit, et il se retrouve
tel quel dans l'onglet Réglages de l'app installée — « 1.0 (26) ». Savoir quel
paquet tourne sur le téléphone, et remonter au commit correspondant, ne demande
donc aucune supposition.

Pour l'installer sur un iPhone depuis Windows ou Linux : télécharge l'artefact
depuis l'onglet Actions, puis signe-le avec ton propre identifiant Apple via
[Sideloadly](https://sideloadly.io) ou [AltStore](https://altstore.io). Avec un
compte Apple gratuit, la signature expire au bout de 7 jours et l'opération est
à refaire ; AltStore peut s'en charger automatiquement en Wi-Fi.

La signature n'est volontairement pas faite en CI : elle demanderait d'y
déposer un certificat de développeur, alors qu'elle appartient à la machine de
celui qui installe l'app.

### Choisir entre AltStore et Sideloadly

Les deux signent le même `.ipa` avec le même identifiant Apple et aboutissent au
même résultat. Ils diffèrent sur ce qu'ils demandent ensuite :

| | AltStore | Sideloadly |
|---|---|---|
| Renouvellement des 7 jours | automatique, en Wi-Fi | à refaire à la main |
| Installation | passe par AltServer, resté ouvert sur le PC | branchement USB direct |
| Pièces mobiles | AltStore, AltServer, iTunes, iCloud | Sideloadly, iTunes, iCloud |

AltStore rend le renouvellement indolore, au prix d'un serveur de plus entre le
téléphone et Apple — c'est lui qui produit l'erreur 2005 documentée plus bas.
Sideloadly supprime cet intermédiaire mais laisse les 7 jours à la charge de
l'utilisateur. Quand le dépannage d'AltStore coûte plus cher que le
renouvellement manuel, le second chemin devient le bon.

### Installer avec Sideloadly

Prérequis Windows, à faire une fois :

1. Si iTunes ou iCloud viennent du **Microsoft Store**, les désinstaller :
   Sideloadly a besoin des versions téléchargées directement chez Apple, seules
   à fournir les composants d'authentification.
2. Installer [iTunes](https://www.apple.com/itunes/) et
   [iCloud](https://support.apple.com/fr-fr/HT204283) depuis le site d'Apple.
3. Redémarrer l'ordinateur.

Puis, à chaque installation :

1. Télécharger l'artefact depuis l'onglet Actions et **décompresser le `.zip`** :
   c'est le `.ipa` qu'il contient qu'on fournit, pas l'archive. Les deux font
   presque la même taille, la confusion est facile.
2. Brancher l'iPhone en USB et le déverrouiller.
3. Glisser le `.ipa` dans Sideloadly, saisir l'identifiant Apple et le code de
   validation en deux étapes.
4. Sur le téléphone, faire confiance au profil : Réglages → Général → VPN et
   gestion de l'appareil → l'identifiant Apple → Faire confiance.

Les limites qui suivent viennent d'Apple et non de l'outil : avec un compte
gratuit, la signature tient 7 jours, trois applications au plus peuvent être
installées ainsi, et dix identifiants d'app peuvent être enregistrés par
semaine.

### Erreur 2005 à l'installation

> *Installation failed — The data couldn't be read because it isn't in the
> correct format.*

Le code 2005 est `AltServer.ServerError`, « AltServer received an invalid
request » : AltServer n'a pas compris ce que l'app lui a envoyé. Le message sur
le format est l'erreur de décodage sous-jacente, pas un défaut du `.ipa`.

Le paquet n'y est pour rien, et ça se vérifie en une minute : réinstalle un
`.ipa` plus ancien qui s'était déjà installé. S'il échoue aussi, cherche du côté
d'AltStore et pas du code. C'est le test qui aurait dû venir en premier.

Deux épisodes, et ce qu'on en sait :

- Le premier s'est résolu après avoir fermé et relancé AltServer, sans
  certitude : plusieurs pistes avaient été tentées de front.
- Le second n'a pas cédé au redémarrage. Il a disparu après avoir désinstallé
  les versions Microsoft Store d'iTunes et d'iCloud, réinstallé celles d'Apple,
  **et** être passé à Sideloadly. Deux changements à la fois, donc là non plus
  on ne sait pas lequel a compté.

Ce que la répétition apprend quand même : un redémarrage qui débloque puis un
échec qui revient exclut l'incompatibilité de version, laquelle échouerait à
tous les coups. C'est un état, pas une incompatibilité.

Dans l'ordre, du plus probable au moins :

1. **Vérifie d'où viennent iTunes et iCloud.** S'ils sortent du Microsoft
   Store, désinstalle-les et reprends-les chez Apple — ce sont eux qui
   fournissent l'authentification, et c'est le suspect numéro un. En
   désinstallant, **ne touche pas** à « Apple Mobile Device Support » ni à
   « Apple Application Support » : ce sont eux qui font voir le téléphone à
   Windows.
2. **Ouvre iTunes et laisse-le tourner** pendant l'installation.
3. **Ferme AltServer et relance-le.**
4. **Lance AltServer en tant qu'administrateur.**
5. **Branche l'iPhone en USB** plutôt que de passer par le Wi-Fi.
6. **Passe à Sideloadly**, qui n'a pas d'AltServer entre le téléphone et Apple
   et ne peut donc pas produire cette erreur.

Références : [codes d'erreur](https://faq.altstore.io/altstore-classic/error-codes)
et [guide de dépannage](https://faq.altstore.io/altstore-classic/troubleshooting-guide)
d'AltStore.

### Apple Santé, en sommeil

La lecture des dépenses énergétiques est écrite et branchée, mais désactivée :
l'entitlement HealthKit n'est pas accordé aux comptes Apple gratuits, et sa
présence fait échouer la signature au moment du sideload. Sans lui, la demande
d'autorisation échoue et la ligne « kcal brûlées » ne s'affiche simplement pas.

Avec un compte développeur payant, il suffit de rétablir deux réglages sur la
cible `CalTracker`, dans les deux configurations :

```
CODE_SIGN_ENTITLEMENTS = CalTracker.entitlements;
INFOPLIST_KEY_NSHealthShareUsageDescription = "…";
```

Le fichier `CalTracker.entitlements` est conservé à la racine pour cela, et
rien d'autre n'est à toucher : la source de données considère HealthKit comme
indisponible tant que la description d'usage manque, et se réactive d'elle-même
dès qu'elle est déclarée.

Cette détection n'est pas un raffinement : demander une autorisation de lecture
sans description d'usage fait lever à HealthKit une exception Objective-C, que
Swift ne peut pas rattraper. L'app se terminait au lancement du journal.

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
  recette au journal. La liste se filtre par type, calories et protéines par
  assiette, matériel disponible et aliments écartés — les mêmes critères que
  l'assistant menus, servis par les mêmes sections de formulaire. Les aliments
  qu'on peut écarter sont rangés par famille (légumes, viandes, produits de la
  mer, œufs et laitages, légumineuses, féculents, fruits, oléagineux,
  épicerie), déduite du nom pour couvrir aussi les ingrédients saisis à la
  main.
- **Catalogue livré** — soixante-dix-neuf recettes protéinées (cinquante-cinq
  repas, vingt-quatre collations) décrites dans `Resources/RecipeCatalogue.json`,
  bâties sur une table de 86 ingrédients de référence, installées au
  premier lancement et complétées à chaque nouvelle version du fichier. Une
  recette supprimée ne revient pas.
- **Assistant menus** — composition d'un planning sur plusieurs jours à partir
  du catalogue, filtré par calories et protéines par assiette, matériel
  disponible et aliments écartés. Une préparation couvre plusieurs repas, comme
  on cuisine réellement, et la liste de courses en découle.
- **Liste de courses** — génération à partir des recettes sélectionnées, mise à
  l'échelle selon le nombre de portions souhaité, fusion des ingrédients
  identiques, exclusion optionnelle des produits de placard, partage en texte.
- **Objectif calculé** — dépense énergétique estimée depuis le poids, la
  taille, l'âge et le niveau d'activité (Mifflin-St Jeor), ajustée selon
  l'objectif choisi (déficit, maintien, prise de masse). Les objectifs saisis à
  la main restent disponibles.
- **Dépenses mesurées** — les calories brûlées lues dans Apple Santé
  s'affichent à côté de l'objectif sans le modifier, pour laisser le choix de
  les compenser ou non.
- **Réglages** — profil corporel, objectifs de macros, état de l'accès à Apple
  Santé, réinstallation du catalogue et version de l'app.

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

Deux services sont interrogés : la recherche plein texte passe par
`search.openfoodfacts.org`, la consultation par code-barres par l'API produit
historique. Ce découpage vient d'une panne observée en production — l'ancien
`cgi/search.pl` répondait 503 alors que le scanner continuait de fonctionner.
Les pannes passagères (5xx, 429, expiration) sont réessayées avec une attente
doublée à chaque tour ; une requête malformée ou une réponse illisible
échouerait à l'identique et n'est pas rejouée.
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
- `RecipeCatalogueTests` — cohérence du catalogue livré, part de protéines de
  chaque recette, installation idempotente, et vivier restant pour chaque
  combinaison de filtres
- `RecipeFilterTests` — fourchettes de calories, plancher de protéines,
  aliments écartés, matériel réclamé, type de recette
- `IngredientFamilyTests` — classement des aliments par famille, noms trompeurs
  compris, et couverture de tout le catalogue livré
- `MealPlannerTests` — répartition des recettes sur les jours, couverture d'une
  préparation, reproductibilité du tirage
- `EnergyCalculatorTests` — métabolisme de base, dépense totale et objectif
  calculé

## Crédits

Les données produits proviennent d'[Open Food Facts](https://world.openfoodfacts.org),
base collaborative sous licence ODbL.
