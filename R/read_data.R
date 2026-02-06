read_design_points <- function(path) {
  pts <- read.csv(path, stringsAsFactors = FALSE)
  pts$location_id <- pts$id
  pts
}

discover_cimis_dates <- function(cimis_root) {
  et_files <- list.files(
    cimis_root,
    pattern = "ETo\\.asc\\.gz$",
    recursive = TRUE,
    full.names = FALSE
  )
  
  dates <- vapply(et_files, function(f) {
    parts <- strsplit(f, "/")[[1]]
    if (length(parts) >= 4) {
      year <- parts[1]
      month <- parts[2]
      day <- parts[3]
      sprintf("%s-%s-%s", year, month, day)
    } else {
      NA_character_
    }
  }, character(1))
  
  dates <- dates[!is.na(dates)]
  dates <- as.Date(dates, format = "%Y-%m-%d")
  dates <- dates[!is.na(dates)]
  sort(dates)
}

discover_chirps_years <- function(chirps_root) {
  files <- list.files(chirps_root, pattern = "chirps-v2\\.0\\.\\d{4}\\.days_p05\\.nc$", full.names = FALSE)
  years <- as.integer(gsub("chirps-v2\\.0\\.(\\d{4})\\.days_p05\\.nc$", "\\1", files))
  sort(years)
}
