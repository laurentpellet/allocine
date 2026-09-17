
films <- fread(FICHIER_FILMS)
tmdb_ids <- fread(FICHIER_TMDB_IDS)
tmdb_ids <- tmdb_ids[order(annee)]
fwrite(tmdb_ids, FICHIER_TMDB_IDS)

#ids <- tmdb_match_all(films)
X <- merge(films[, .(NbFilms=.N), annee], tmdb_ids[, .(NbTMDB=.N), annee], by="annee", all=TRUE)[,Diff:=NbFilms-NbTMDB]
#[, (Desc=NbFilms-NbTMDB)]
X

tmdb_ids[, .N, match_type]
