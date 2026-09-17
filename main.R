source("src/functions.R")

DATE_DEBUT <- as.Date("2015-01-01")
DATE_FIN <- as.Date("2026-09-16")

# ALLOCINE - TELECHARGEMENT -----------------------------------------------
premier_mercredi <- function(date) {
  while (format(date, "%u") != "3") date <- date + 1
  date
}

mercredis <- seq(premier_mercredi(DATE_DEBUT), DATE_FIN, by = "7 days")

for (date in mercredis) {
  date <- as.Date(date, origin = "1970-01-01")
  dossier <- file.path(DOSSIER_ALLOCINE, format(date, "%Y"))
  fichier <- file.path(dossier, paste0("allocine_", date, ".csv"))
  
  dir.create(dossier, showWarnings = FALSE)
  
  if (file.exists(fichier)) {
    message(date, " : déjà téléchargé")
    next
  }
  
  films <- allocine_week(date) |>
    mutate(semaine = date, .before = 1)
  fwrite(films, fichier)
  message("Enregistré : ", fichier)
}


# ALLOCINE - CONSOLIDATION ------------------------------------------------
fichiers <- list.files(DOSSIER_ALLOCINE,"^allocine_\\d{4}-\\d{2}-\\d{2}\\.csv$", recursive = TRUE, full.names = TRUE)
films <- fichiers |>
  lapply(fread) |>
  rbindlist(fill = TRUE)
films[, date_sortie := as.IDate(date_sortie, format = "%d %B %Y")]
films[, annee := year(date_sortie)]
setorder(films, date_sortie)
fwrite(films, FICHIER_FILMS)

# ALLOCINE - ACTEURS ------------------------------------------------------
acteurs <- films[!is.na(cast), .(acteur = trimws(unlist(strsplit(cast, ",", fixed = TRUE)))), by = .(allocine_id, titre, annee)]
acteurs <- unique(acteurs[acteur != ""])
fwrite(acteurs, FICHIER_ACTEURS)

# TMDB - MATCHING ---------------------------------------------------------
tmdb_ids <- tmdb_match_all(films, cache_file = FICHIER_TMDB_IDS)
message("\nTMDb : ", tmdb_ids[!is.na(tmdb_id), .N], " trouvés / ", nrow(tmdb_ids), " films")
print(tmdb_ids[, .N, by = match_type][order(-N)])

ids <- tmdb_ids[!is.na(tmdb_id), unique(tmdb_id)]
if (file.exists(FICHIER_TMDB_FILMS)) {
  films_tmdb <- fread(FICHIER_TMDB_FILMS)
  ids_faits <- unique(films_tmdb$tmdb_id)
} else {
  films_tmdb <- data.table()
  ids_faits <- integer()
}

ids <- setdiff(ids, ids_faits)
message("\n", length(ids), " films TMDb à télécharger")

for (i in seq_along(ids)) {
  id <- ids[i]
  message(i, "/", length(ids), " - TMDB : ", id)
  x <- tryCatch(
    tmdb_movie(id),
    error = function(e) {
      message("ERREUR : ", e$message)
      NULL
    }
  )
  
  if (is.null(x)) next
  
  film <- parse_movie(x)
  cast <- parse_cast(x)
  crew <- parse_crew(x)
  existe <- file.exists(FICHIER_TMDB_FILMS)
  fwrite(film, FICHIER_TMDB_FILMS, append = existe, col.names = !existe)
  if (nrow(cast)) {
    existe <- file.exists(FICHIER_TMDB_CAST)
    fwrite(cast, FICHIER_TMDB_CAST, append = existe, col.names = !existe)
  }
  
  if (nrow(crew)) {
    existe <- file.exists(FICHIER_TMDB_CREW)
    fwrite(crew, FICHIER_TMDB_CREW, append = existe, col.names = !existe)
  }
}

# TMDB - CHARGEMENT -------------------------------------------------------
films_tmdb <- if (file.exists(FICHIER_TMDB_FILMS)) fread(FICHIER_TMDB_FILMS) else data.table()
cast_tmdb <- if (file.exists(FICHIER_TMDB_CAST)) fread(FICHIER_TMDB_CAST) else data.table()
crew_tmdb <- if (file.exists(FICHIER_TMDB_CREW)) fread(FICHIER_TMDB_CREW) else data.table()

# RESULTATS ---------------------------------------------------------------
message("\nAlloCiné : ", nrow(films), " films")
message("TMDb matchés : ", tmdb_ids[!is.na(tmdb_id), .N])
message("TMDb détails : ", nrow(films_tmdb))
message("TMDb cast : ", nrow(cast_tmdb), " crédits")
message("TMDb crew : ", nrow(crew_tmdb), " crédits")