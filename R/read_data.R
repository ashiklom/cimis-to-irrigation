read_design_points <- function(path) {
  readr::read_csv(
    path,
    col_types = readr::cols(
      id = readr::col_character(),
      lat = readr::col_double(),
      lon = readr::col_double()
    )
  ) |>
    dplyr::rename(location_id = .data$id)
}

discover_cimis_dates <- function(cimis_root) {
  et_files <- list.files(
    cimis_root,
    pattern = "ETo\\.asc\\.gz$",
    recursive = TRUE,
    full.names = FALSE
  )

  dates <- purrr::map_chr(et_files, function(f) {
    parts <- strsplit(f, "/")[[1]]
    if (length(parts) >= 4) {
      glue::glue("{parts[1]}-{parts[2]}-{parts[3]}")
    } else {
      NA_character_
    }
  })

  dates |>
    purrr::keep(~ !is.na(.x)) |>
    as.Date(format = "%Y-%m-%d") |>
    purrr::keep(~ !is.na(.x)) |>
    sort()
}

discover_chirps_years <- function(chirps_root) {
  files <- list.files(
    chirps_root,
    pattern = "chirps-v2\\.0\\.\\d{4}\\.days_p05\\.nc$",
    full.names = FALSE
  )

  files |>
    gsub("chirps-v2\\.0\\.(\\d{4})\\.days_p05\\.nc$", "\\1", x = _) |>
    as.integer() |>
    sort()
}

.data <- rlang::.data
