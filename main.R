source("src/functions.R")

DATE_DEBUT <- as.Date("2025-11-01")
DATE_FIN <- as.Date("2026-09-16")
dir.create(DOSSIER_ALLOCINE, recursive = TRUE, showWarnings = FALSE)
dir.create(DOSSIER_TMDB, recursive = TRUE, showWarnings = FALSE)

# ALLOCINE ---------------------------------------------------------------
allocine_download(DATE_DEBUT, DATE_FIN, DOSSIER_ALLOCINE)
films <- allocine_consolidate(DOSSIER_ALLOCINE)
fwrite(films, FICHIER_FILMS)
acteurs <- allocine_acteurs(films)
fwrite(acteurs, FICHIER_ACTEURS)

# TMDB - MATCHING ---------------------------------------------------------
tmdb_ids <- tmdb_match_all(films, FICHIER_TMDB_IDS, save_every = 100)
message("\nTMDb : ", tmdb_ids[!is.na(tmdb_id), .N], " trouvés / ", nrow(tmdb_ids), " films")
print(tmdb_ids[, .N, by = match_type][order(-N)])
ids <- tmdb_ids[!is.na(tmdb_id), unique(tmdb_id)]
tmdb_download_details(ids, FICHIER_TMDB_FILMS, FICHIER_TMDB_CAST, FICHIER_TMDB_CREW, save_every = 100)


# RESULTATS ---------------------------------------------------------------
message("\nAlloCiné : ", nrow(films), " films")
message("TMDb matchés : ", tmdb_ids[!is.na(tmdb_id), .N])