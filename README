# AlloCiné / TMDb Dataset

Projet R permettant de constituer et maintenir une base de données de films à partir des sorties hebdomadaires **AlloCiné**, puis de l'enrichir avec les données de **TMDb** et les identifiants **IMDb**.

Le traitement utilise plusieurs niveaux de cache afin de pouvoir être relancé sans retélécharger les données déjà collectées.

## Fonctionnalités

Le projet permet de :

* récupérer les sorties cinéma hebdomadaires depuis AlloCiné ;
* extraire les informations principales de chaque film ;
* consolider les fichiers hebdomadaires dans une base unique ;
* extraire la liste des acteurs mentionnés par AlloCiné ;
* rechercher automatiquement le film correspondant dans TMDb ;
* rapprocher les films sur le titre, le titre original et l'année ;
* récupérer les identifiants TMDb et IMDb ;
* récupérer les informations détaillées TMDb ;
* récupérer le casting et l'équipe technique ;
* reprendre automatiquement un traitement interrompu grâce aux caches.

## Structure du projet

```text
.
├── main.R
├── README.md
│
├── src/
│   └── functions.R
│
└── data/
    ├── allocine/
    │   ├── 2015/
    │   │   ├── allocine_2015-01-07.csv
    │   │   ├── allocine_2015-01-14.csv
    │   │   └── ...
    │   ├── 2016/
    │   └── ...
    │
    ├── tmdb/
    │   ├── films.csv
    │   ├── cast.csv
    │   └── crew.csv
    │
    ├── films.csv
    ├── acteurs.csv
    └── tmdb_ids.csv
```

## Dépendances

Le projet utilise les packages R suivants :

```r
install.packages(c(
  "httr2",
  "rvest",
  "stringr",
  "dplyr",
  "purrr",
  "tibble",
  "data.table",
  "stringdist",
  "stringi",
  "lubridate"
))
```

## Configuration TMDb

L'accès à l'API TMDb nécessite un token API.

Il est recommandé de ne pas placer ce token directement dans `functions.R`.

Ajouter dans le fichier `.Renviron` :

```text
TMDB_TOKEN=VOTRE_TOKEN_TMDB
```

Puis redémarrer la session R.

Le token est récupéré par :

```r
TMDB_TOKEN <- Sys.getenv("TMDB_TOKEN")
```

## Configuration

La période à traiter est définie au début de `main.R` :

```r
DATE_DEBUT <- as.Date("2015-01-01")
DATE_FIN <- as.Date("2026-09-16")
```

Les sorties cinéma sont recherchées semaine par semaine, le mercredi.

## Collecte AlloCiné

Pour chaque mercredi compris entre `DATE_DEBUT` et `DATE_FIN`, le programme interroge la page des sorties hebdomadaires AlloCiné.

Les films sont enregistrés dans :

```text
data/allocine/YYYY/allocine_YYYY-MM-DD.csv
```

Exemple :

```text
data/allocine/2026/allocine_2026-09-16.csv
```

Chaque fichier contient notamment :

| Champ              | Description               |
| ------------------ | ------------------------- |
| `allocine_id`      | Identifiant AlloCiné      |
| `titre`            | Titre français            |
| `titre_original`   | Titre original            |
| `date_sortie`      | Date de sortie française  |
| `duree`            | Durée                     |
| `genres`           | Genres                    |
| `realisateur`      | Réalisateur               |
| `scenaristes`      | Scénaristes               |
| `cast`             | Principaux acteurs        |
| `synopsis`         | Synopsis                  |
| `nationalite`      | Nationalité               |
| `annee_production` | Année de production       |
| `distributeur`     | Distributeur              |
| `langues`          | Langues                   |
| `budget`           | Budget                    |
| `boxoffice_france` | Box-office France         |
| `note_presse`      | Note presse AlloCiné      |
| `note_spectateurs` | Note spectateurs AlloCiné |

### Cache AlloCiné

Avant chaque téléchargement, le programme vérifie si le fichier hebdomadaire existe déjà.

```r
if (file.exists(fichier)) {
  message(date, " : déjà téléchargé")
  next
}
```

Une semaine déjà collectée n'est donc pas téléchargée à nouveau.

## Consolidation

Tous les fichiers hebdomadaires sont ensuite regroupés dans :

```text
data/films.csv
```

La variable `annee` est calculée à partir de la date de sortie.

Les films sont triés chronologiquement.

## Acteurs AlloCiné

Le champ `cast` fourni par AlloCiné est décomposé afin de produire :

```text
data/acteurs.csv
```

Structure :

```text
allocine_id
titre
annee
acteur
```

Ce fichier correspond au casting simplifié récupéré depuis les fiches AlloCiné.

Le casting TMDb complet est disponible séparément dans `data/tmdb/cast.csv`.

## Matching AlloCiné → TMDb

Chaque film AlloCiné est recherché dans TMDb.

Le rapprochement utilise :

* le titre français ;
* le titre original lorsqu'il est disponible ;
* l'année de sortie ;
* une similarité Jaro-Winkler entre les titres.

La similarité est calculée avec :

```r
stringdist::stringsim(..., method = "jw")
```

Le score final combine :

```text
80 % similarité du titre
20 % proximité de l'année
```

La proximité de l'année tolère un décalage entre la date de sortie française et la date de sortie internationale.

Le résultat du rapprochement est stocké dans :

```text
data/tmdb_ids.csv
```

Principales colonnes :

| Champ                 | Description              |
| --------------------- | ------------------------ |
| `allocine_id`         | Identifiant AlloCiné     |
| `tmdb_id`             | Identifiant TMDb         |
| `imdb_id`             | Identifiant IMDb         |
| `tmdb_titre`          | Titre trouvé dans TMDb   |
| `tmdb_titre_original` | Titre original TMDb      |
| `tmdb_annee`          | Année TMDb               |
| `match_score`         | Score de rapprochement   |
| `match_type`          | Qualité du rapprochement |

Les catégories utilisées sont :

```text
excellent   score >= 0.95
bon         score >= 0.85
incertain   score >= 0.70
faible      score <  0.70
aucun       aucun candidat trouvé
erreur      erreur lors de l'appel API
```

Ces catégories servent au contrôle du rapprochement et ne correspondent pas à une note du film.

## Cache du matching TMDb

`data/tmdb_ids.csv` sert de cache permanent.

Lors d'une nouvelle exécution, les films déjà présents ne sont pas recherchés une seconde fois.

Les résultats `aucun` sont également conservés afin d'éviter de répéter inutilement une recherche infructueuse.

Les lignes ayant :

```text
match_type = erreur
```

sont en revanche supprimées du cache de travail et retentées lors de l'exécution suivante.

Cela permet de reprendre automatiquement après une erreur réseau ou une indisponibilité temporaire de l'API.

## Détails TMDb

Après le matching, les informations détaillées sont récupérées pour chaque `tmdb_id`.

Le programme récupère notamment :

* titre ;
* titre original ;
* langue originale ;
* date de sortie ;
* synopsis ;
* tagline ;
* durée ;
* budget ;
* recettes ;
* popularité ;
* note TMDb ;
* nombre de votes ;
* genres ;
* pays ;
* langues ;
* sociétés de production ;
* identifiant IMDb ;
* casting ;
* équipe technique.

Les données sont réparties dans trois fichiers.

### Films

```text
data/tmdb/films.csv
```

Une ligne correspond à un film TMDb.

### Casting

```text
data/tmdb/cast.csv
```

Une ligne correspond à la participation d'une personne à un film en tant qu'acteur.

Principales variables :

```text
tmdb_id
person_id
nom
nom_original
personnage
ordre
genre
popularite
profile_path
```

### Équipe technique

```text
data/tmdb/crew.csv
```

Une ligne correspond à un crédit technique.

Principales variables :

```text
tmdb_id
person_id
nom
departement
poste
credit_id
```

## Cache des détails TMDb

Le fichier :

```text
data/tmdb/films.csv
```

sert de référence pour déterminer les films déjà récupérés.

Le programme calcule :

```r
ids <- setdiff(ids, ids_faits)
```

Seuls les nouveaux `tmdb_id` sont donc interrogés.

Après chaque réponse TMDb, les données sont ajoutées directement aux fichiers :

```text
films.csv
cast.csv
crew.csv
```

avec `fwrite(..., append = TRUE)`.

Cette stratégie évite de conserver l'intégralité des données en mémoire et permet de reprendre un téléchargement interrompu.

## Niveaux de cache

Le projet possède donc trois niveaux de reprise :

```text
AlloCiné
   │
   ├── cache hebdomadaire
   │   data/allocine/YYYY/*.csv
   │
   ▼
films.csv
   │
   ├── cache matching
   │   data/tmdb_ids.csv
   │
   ▼
TMDb ID / IMDb ID
   │
   ├── cache détails
   │   data/tmdb/films.csv
   │
   ▼
cast.csv / crew.csv
```

Un nouveau lancement peut ainsi reprendre le traitement sans recommencer les étapes déjà terminées.

## Exécution

Depuis la racine du projet :

```r
source("main.R")
```

ou depuis un terminal :

```bash
Rscript main.R
```

Le script :

1. télécharge les nouvelles semaines AlloCiné ;
2. reconstruit `films.csv` ;
3. reconstruit `acteurs.csv` ;
4. recherche les nouveaux films dans TMDb ;
5. met à jour `tmdb_ids.csv` ;
6. télécharge les détails des nouveaux films TMDb ;
7. complète les caches `films.csv`, `cast.csv` et `crew.csv`.

## Contrôle du matching

Les rapprochements incertains peuvent être examinés avec :

```r
tmdb_ids[
  is.na(tmdb_id) | match_score < .85,
  .(
    allocine_id,
    titre,
    annee,
    tmdb_titre,
    tmdb_annee,
    match_score,
    match_type
  )
][order(match_score)]
```

La distribution des résultats peut être obtenue avec :

```r
tmdb_ids[, .N, by = match_type][order(-N)]
```

## Données personnes

`functions.R` contient également les fonctions permettant d'interroger une personne TMDb :

```r
tmdb_person(person_id)
parse_person(x)
```

Les informations disponibles comprennent notamment :

* identifiant TMDb de la personne ;
* identifiant IMDb ;
* identifiant Wikidata ;
* nom ;
* date de naissance ;
* date de décès ;
* lieu de naissance ;
* département principal ;
* biographie ;
* popularité ;
* photo de profil.

Cette partie n'est pas encore intégrée au traitement principal.

## Limites

Le scraping AlloCiné dépend de la structure HTML du site. Une modification du site peut nécessiter une adaptation des sélecteurs ou expressions régulières.

Le matching AlloCiné → TMDb est probabiliste. Les films ayant des titres identiques, des ressorties, des remakes ou des dates de sortie très différentes peuvent nécessiter une vérification manuelle.

Les données provenant d'AlloCiné et TMDb restent soumises aux conditions d'utilisation et licences de leurs fournisseurs respectifs.

## Fichiers principaux

```text
main.R
```

Orchestre l'ensemble du traitement et la gestion des caches.

```text
src/functions.R
```

Contient les fonctions de scraping AlloCiné, les appels à l'API TMDb, le matching et les parseurs.

```text
data/tmdb_ids.csv
```

Table de correspondance centrale :

```text
AlloCiné ID ↔ TMDb ID ↔ IMDb ID
```
