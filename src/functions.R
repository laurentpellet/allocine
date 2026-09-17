library(httr2)
library(rvest)
library(stringr)
library(dplyr)
library(purrr)
library(tibble)
library(data.table)
library(stringdist)
library(stringi)
library(lubridate)

BASE_URL <- "https://www.allocine.fr"
TMDB_URL <- "https://api.themoviedb.org/3"
#TMDB_TOKEN <- "eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiI3YjY1MTUzMzM3NDVlY2ZhN2FiODE1OTYzNGNiNjZlMiIsIm5iZiI6MTY2OTE4ODI2Ny45NjQsInN1YiI6IjYzN2RjYWFiNTliYzA3MDBjZjYwZTZlNyIsInNjb3BlcyI6WyJhcGlfcmVhZCJdLCJ2ZXJzaW9uIjoxfQ.YPkkDK_ci-RJWXbHwPy2FRnJj_4oVqIr5M35w7Nc7t0"
TMDB_TOKEN <- Sys.getenv("TMDB_TOKEN")

DOSSIER_ALLOCINE <- "data/allocine"
DOSSIER_TMDB <- "data/tmdb"

FICHIER_FILMS <- "data/films.csv"
FICHIER_ACTEURS <- "data/acteurs.csv"
FICHIER_TMDB_IDS <- "data/tmdb_ids.csv"

FICHIER_TMDB_FILMS <- file.path(DOSSIER_TMDB, "films.csv")
FICHIER_TMDB_CAST <- file.path(DOSSIER_TMDB, "cast.csv")
FICHIER_TMDB_CREW <- file.path(DOSSIER_TMDB, "crew.csv")

dir.create(DOSSIER_ALLOCINE, recursive = TRUE, showWarnings = FALSE)
dir.create(DOSSIER_TMDB, recursive = TRUE, showWarnings = FALSE)


# UTILITAIRES -------------------------------------------------------------

`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0) y else x
}

parse_note <- function(x) {
  x |>
    str_extract("[0-5][,.][0-9]") |>
    str_replace(",", ".") |>
    as.numeric()
}

extract_match <- function(x, pattern) {
  m <- str_match(x, pattern)
  if (is.na(m[1, 2])) return(NA_character_)
  str_trim(m[1, 2])
}

get_text <- function(html, selector) {
  x <- html |> html_element(selector)
  if (length(x) == 0 || is.na(x)) return(NA_character_)
  html_text2(x)
}

normalize_title <- function(x) {
  x <- stri_trans_general(x, "Latin-ASCII")
  x <- tolower(x)
  x <- gsub("[^a-z0-9 ]", " ", x)
  x <- gsub("\\s+", " ", x)
  trimws(x)
}


# ALLOCINE - REQUETES -----------------------------------------------------

get_html <- function(url) {
  request(url) |>
    req_user_agent("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/140 Safari/537.36") |>
    req_headers(`Accept-Language` = "fr-FR,fr;q=0.9,en;q=0.8") |>
    req_retry(max_tries = 3) |>
    req_perform() |>
    resp_body_html()
}


# ALLOCINE - FILM ---------------------------------------------------------

allocine_movie <- function(url) {
  html <- get_html(url)
  
  id <- url |>
    str_extract("cfilm=\\d+") |>
    str_remove("cfilm=") |>
    as.integer()
  
  titre <- get_text(html, ".titlebar-title")
  synopsis <- get_text(html, ".content-txt")
  
  texte <- html |>
    html_element("body") |>
    html_text2()
  
  date_sortie <- texte |>
    str_extract("\\d{1,2}\\s+(janvier|février|mars|avril|mai|juin|juillet|août|septembre|octobre|novembre|décembre)\\s+\\d{4}")
  
  duree <- texte |> str_extract("\\d+h\\s*\\d+min")
  
  realisateur <- extract_match(texte, "\\bDe\\s+([^\\n|]+)")
  scenaristes <- extract_match(texte, "\\bPar\\s+([^\\n]+)")
  cast <- extract_match(texte, "\\bAvec\\s+([^\\n]+)")
  titre_original <- extract_match(texte, "Titre original\\s+([^\\n]+)")
  
  genres <- html |>
    html_elements(".meta-body-item.meta-body-info .dark-grey-link") |>
    html_text2()
  
  genres <- if (length(genres))
    paste(unique(genres), collapse = ", ")
  else NA_character_
  
  ratings <- html |>
    html_elements(".rating-item") |>
    html_text2()
  
  presse <- ratings[str_detect(ratings, regex("Presse", ignore_case = TRUE))]
  spectateurs <- ratings[str_detect(ratings, regex("Spectateurs", ignore_case = TRUE))]
  
  note_presse <- if (length(presse)) parse_note(presse[1]) else NA_real_
  note_spectateurs <- if (length(spectateurs)) parse_note(spectateurs[1]) else NA_real_
  
  get_info <- function(label)
    extract_match(texte, paste0(label, "\\s+([^\\n]+)"))
  
  nationalite <- get_info("Nationalités?")
  distributeur <- get_info("Distributeur")
  annee_production <- get_info("Année de production")
  type_film <- get_info("Type de film")
  langues <- get_info("Langues")
  budget <- get_info("Budget")
  boxoffice_france <- get_info("Box Office France")
  couleur <- get_info("Couleur")
  visa <- get_info("N° de Visa")
  
  message("Titre : ", titre)
  
  tibble(
    allocine_id = id,
    titre,
    titre_original,
    date_sortie,
    duree,
    genres,
    realisateur,
    scenaristes,
    cast,
    synopsis,
    nationalite,
    annee_production,
    distributeur,
    type_film,
    langues,
    budget,
    boxoffice_france,
    couleur,
    visa,
    note_presse,
    note_spectateurs,
    url
  )
}


# ALLOCINE - SORTIES HEBDOMADAIRES ---------------------------------------

get_movie_links <- function(html) {
  links <- html |>
    html_elements("a") |>
    html_attr("href")
  
  links <- links[str_detect(links, "^/film/fichefilm_gen_cfilm=\\d+\\.html")]
  
  paste0(BASE_URL, unique(links))
}

allocine_week <- function(date = Sys.Date()) {
  date <- as.Date(date)
  url <- paste0(BASE_URL, "/film/agenda/sem-", format(date, "%Y-%m-%d"))
  
  message("Semaine : ", date)
  message("URL : ", url)
  
  html <- get_html(url)
  links <- get_movie_links(html)
  
  message(length(links), " films trouvés")
  
  if (!length(links)) return(tibble())
  
  map_dfr(links, possibly(allocine_movie, otherwise = tibble())) |>
    distinct(allocine_id, .keep_all = TRUE)
}


# TMDB - REQUETES ---------------------------------------------------------

tmdb_get <- function(path, ...) {
  request(paste0(TMDB_URL, path)) |>
    req_headers(
      Authorization = paste("Bearer", TMDB_TOKEN),
      Accept = "application/json"
    ) |>
    req_url_query(...) |>
    req_retry(max_tries = 3) |>
    req_perform() |>
    resp_body_json(simplifyVector = FALSE)
}

tmdb_get_vector <- function(path, ...) {
  request(paste0(TMDB_URL, path)) |>
    req_headers(
      Authorization = paste("Bearer", TMDB_TOKEN),
      Accept = "application/json"
    ) |>
    req_url_query(...) |>
    req_retry(max_tries = 3) |>
    req_perform() |>
    resp_body_json(simplifyVector = TRUE)
}


# TMDB - RECHERCHE --------------------------------------------------------

tmdb_search_raw <- function(titre, annee = NA) {
  req <- request(paste0(TMDB_URL, "/search/movie")) |>
    req_headers(
      Authorization = paste("Bearer", TMDB_TOKEN),
      Accept = "application/json"
    ) |>
    req_url_query(
      query = titre,
      language = "fr-FR",
      include_adult = "false"
    )
  
  if (!is.na(annee))
    req <- req |> req_url_query(year = annee)
  
  req |>
    req_retry(max_tries = 3) |>
    req_perform() |>
    resp_body_json(simplifyVector = TRUE)
}

tmdb_candidates <- function(titre, annee = NA) {
  x <- tmdb_search_raw(titre, annee)
  
  if (is.null(x$results) || !NROW(x$results))
    return(data.table())
  
  r <- as.data.table(x$results)
  
  if (!"release_date" %in% names(r))
    r[, release_date := NA_character_]
  
  r[, tmdb_annee := suppressWarnings(as.integer(substr(release_date, 1, 4)))]
  
  r[, .(
    tmdb_id = id,
    tmdb_titre = title,
    tmdb_titre_original = original_title,
    tmdb_annee,
    popularity,
    vote_average,
    vote_count
  )]
}

tmdb_imdb_id <- function(tmdb_id) {
  x <- tmdb_get_vector(paste0("/movie/", tmdb_id, "/external_ids"))
  
  if (is.null(x$imdb_id) || !length(x$imdb_id))
    return(NA_character_)
  
  x$imdb_id
}


# TMDB - MATCHING ALLOCINE ------------------------------------------------

tmdb_match <- function(titre, titre_original = NA, annee = NA) {
  recherches <- unique(c(titre, titre_original))
  recherches <- recherches[!is.na(recherches) & recherches != ""]
  
  candidats <- rbindlist(lapply(recherches, function(recherche) {
    r <- tmdb_candidates(recherche, annee)
    if (nrow(r)) r[, recherche := recherche]
    r
  }), fill = TRUE)
  
  if (!nrow(candidats)) {
    return(data.table(
      tmdb_id = NA_integer_,
      imdb_id = NA_character_,
      tmdb_titre = NA_character_,
      tmdb_titre_original = NA_character_,
      tmdb_annee = NA_integer_,
      match_score = NA_real_,
      match_type = "aucun"
    ))
  }
  
  ntitre <- normalize_title(titre)
  
  candidats[, score_titre := pmax(
    stringdist::stringsim(normalize_title(tmdb_titre), ntitre, method = "jw"),
    stringdist::stringsim(normalize_title(tmdb_titre_original), ntitre, method = "jw"),
    na.rm = TRUE
  )]
  
  if (!is.na(titre_original) && titre_original != "") {
    noriginal <- normalize_title(titre_original)
    
    candidats[, score_original := pmax(
      stringdist::stringsim(normalize_title(tmdb_titre), noriginal, method = "jw"),
      stringdist::stringsim(normalize_title(tmdb_titre_original), noriginal, method = "jw"),
      na.rm = TRUE
    )]
    
    candidats[, score_titre := pmax(score_titre, score_original, na.rm = TRUE)]
  }
  
  if (!is.na(annee)) {
    candidats[, ecart_annee := abs(tmdb_annee - annee)]
    candidats[, score_annee := fifelse(
      is.na(ecart_annee), 0,
      fifelse(ecart_annee == 0, 1,
              fifelse(ecart_annee == 1, .8,
                      fifelse(ecart_annee == 2, .5, 0)))
    )]
  } else candidats[, score_annee := 0]
  
  candidats[, match_score := score_titre * .8 + score_annee * .2]
  setorder(candidats, -match_score, -popularity)
  
  best <- candidats[1]
  imdb_id <- tryCatch(tmdb_imdb_id(best$tmdb_id), error = function(e) NA_character_)
  
  match_type <- if (best$match_score >= .95) "excellent"
  else if (best$match_score >= .85) "bon"
  else if (best$match_score >= .70) "incertain"
  else "faible"
  
  data.table(
    tmdb_id = best$tmdb_id,
    imdb_id,
    tmdb_titre = best$tmdb_titre,
    tmdb_titre_original = best$tmdb_titre_original,
    tmdb_annee = best$tmdb_annee,
    match_score = round(best$match_score, 3),
    match_type
  )
}


# TMDB - CACHE MATCHING ---------------------------------------------------

tmdb_match_all <- function(films, cache_file = "data/tmdb_ids.csv") {
  todo <- unique(films[, .(
    allocine_id,
    titre,
    titre_original,
    annee
  )])
  
  todo <- todo[!is.na(allocine_id) & !is.na(titre) & titre != ""]
  
  if (file.exists(cache_file)) {
    cache <- fread(cache_file)
    
    # Les erreurs sont retentées
    cache <- cache[match_type != "erreur"]
    todo <- todo[!allocine_id %in% cache$allocine_id]
  } else cache <- data.table()
  
  message(nrow(todo), " films à matcher avec TMDb")
  
  if (!nrow(todo)) return(cache)
  
  for (i in seq_len(nrow(todo))) {
    x <- todo[i]
    
    message(
      i, "/", nrow(todo),
      " - ", x$titre,
      if (!is.na(x$annee)) paste0(" (", x$annee, ")") else ""
    )
    
    r <- tryCatch(
      tmdb_match(x$titre, x$titre_original, x$annee),
      error = function(e) {
        message("ERREUR : ", e$message)
        
        data.table(
          tmdb_id = NA_integer_,
          imdb_id = NA_character_,
          tmdb_titre = NA_character_,
          tmdb_titre_original = NA_character_,
          tmdb_annee = NA_integer_,
          match_score = NA_real_,
          match_type = "erreur"
        )
      }
    )
    
    ligne <- cbind(
      data.table(
        allocine_id = x$allocine_id,
        titre = x$titre,
        titre_original = x$titre_original,
        annee = x$annee
      ),
      r
    )
    
    cache <- rbindlist(list(cache, ligne), fill = TRUE)
    fwrite(cache, cache_file)
  }
  
  cache
}


# TMDB - DETAILS FILM -----------------------------------------------------

tmdb_movie <- function(tmdb_id) {
  tmdb_get(
    paste0("/movie/", tmdb_id),
    language = "fr-FR",
    append_to_response = "credits,external_ids,release_dates,keywords,videos,alternative_titles"
  )
}

parse_movie <- function(x) {
  data.table(
    tmdb_id = x$id,
    imdb_id = x$imdb_id %||% NA_character_,
    titre = x$title %||% NA_character_,
    titre_original = x$original_title %||% NA_character_,
    langue_originale = x$original_language %||% NA_character_,
    date_sortie = x$release_date %||% NA_character_,
    synopsis = x$overview %||% NA_character_,
    tagline = x$tagline %||% NA_character_,
    duree = x$runtime %||% NA_integer_,
    budget = x$budget %||% NA_real_,
    revenue = x$revenue %||% NA_real_,
    popularite = x$popularity %||% NA_real_,
    note_tmdb = x$vote_average %||% NA_real_,
    nb_votes_tmdb = x$vote_count %||% NA_integer_,
    statut = x$status %||% NA_character_,
    homepage = x$homepage %||% NA_character_,
    poster = x$poster_path %||% NA_character_,
    backdrop = x$backdrop_path %||% NA_character_,
    genres = paste(vapply(x$genres, \(z) z$name, ""), collapse = ", "),
    pays = paste(vapply(x$production_countries, \(z) z$iso_3166_1, ""), collapse = ", "),
    langues = paste(vapply(x$spoken_languages, \(z) z$iso_639_1, ""), collapse = ", "),
    production = paste(vapply(x$production_companies, \(z) z$name, ""), collapse = ", ")
  )
}


# TMDB - CAST -------------------------------------------------------------

parse_cast <- function(x) {
  if (!length(x$credits$cast)) return(data.table())
  
  rbindlist(lapply(x$credits$cast, function(a) {
    data.table(
      tmdb_id = x$id,
      person_id = a$id,
      nom = a$name,
      nom_original = a$original_name,
      personnage = a$character,
      ordre = a$order,
      genre = a$gender,
      popularite = a$popularity,
      profile_path = a$profile_path
    )
  }), fill = TRUE)
}


# TMDB - CREW -------------------------------------------------------------

parse_crew <- function(x) {
  if (!length(x$credits$crew)) return(data.table())
  
  rbindlist(lapply(x$credits$crew, function(a) {
    data.table(
      tmdb_id = x$id,
      person_id = a$id,
      nom = a$name,
      departement = a$department,
      poste = a$job,
      credit_id = a$credit_id
    )
  }), fill = TRUE)
}


# TMDB - PERSONNES --------------------------------------------------------

tmdb_person <- function(person_id) {
  tmdb_get(
    paste0("/person/", person_id),
    language = "fr-FR",
    append_to_response = "external_ids,movie_credits"
  )
}

parse_person <- function(x) {
  data.table(
    person_id = x$id,
    imdb_id = x$external_ids$imdb_id %||% NA_character_,
    wikidata_id = x$external_ids$wikidata_id %||% NA_character_,
    nom = x$name %||% NA_character_,
    nom_original = x$original_name %||% NA_character_,
    date_naissance = x$birthday %||% NA_character_,
    date_deces = x$deathday %||% NA_character_,
    lieu_naissance = x$place_of_birth %||% NA_character_,
    departement = x$known_for_department %||% NA_character_,
    biographie = x$biography %||% NA_character_,
    popularite = x$popularity %||% NA_real_,
    profile_path = x$profile_path %||% NA_character_,
    homepage = x$homepage %||% NA_character_
  )
}