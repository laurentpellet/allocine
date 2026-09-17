DOSSIER_POSTERS <- file.path(DOSSIER_TMDB, "posters")
DOSSIER_BACKDROPS <- file.path(DOSSIER_TMDB, "backdrops")
TMDB_POSTER_URL <- "https://image.tmdb.org/t/p/w600_and_h900_face"
TMDB_BACKDROP_URL <- "https://image.tmdb.org/t/p/w1280"
dir.create(DOSSIER_POSTERS, recursive = TRUE, showWarnings = FALSE)
dir.create(DOSSIER_BACKDROPS, recursive = TRUE, showWarnings = FALSE)


# TMDB - POSTERS ----------------------------------------------------------
posters <- films_tmdb[!is.na(poster) & poster != "", .(tmdb_id, image = poster)]
for (i in seq_len(nrow(posters))) {
  id <- posters[i, tmdb_id]
  image <- posters[i, image]
  extension <- tools::file_ext(image)
  fichier <- file.path(DOSSIER_POSTERS, paste0(id, ".", extension))
  if (file.exists(fichier)) next
  message(i, "/", nrow(posters), " - Poster TMDB : ", id)
  tryCatch(
    request(paste0(TMDB_POSTER_URL, image)) |>
      req_retry(max_tries = 3) |>
      req_perform(path = fichier),
    error = function(e) message("ERREUR : ", e$message)
  )
}


# TMDB - BACKDROPS --------------------------------------------------------
backdrops <- films_tmdb[  !is.na(backdrop) & backdrop != "", .(tmdb_id, image = backdrop)]
for (i in seq_len(nrow(backdrops))) {
  id <- backdrops[i, tmdb_id]
  image <- backdrops[i, image]
  extension <- tools::file_ext(image)
  fichier <- file.path(DOSSIER_BACKDROPS, paste0(id, ".", extension))
  if (file.exists(fichier)) next
  message(i, "/", nrow(backdrops), " - Backdrop TMDB : ", id)
  tryCatch(
    request(paste0(TMDB_BACKDROP_URL, image)) |>
      req_retry(max_tries = 3) |>
      req_perform(path = fichier),
    error = function(e) message("ERREUR : ", e$message)
  )
}
