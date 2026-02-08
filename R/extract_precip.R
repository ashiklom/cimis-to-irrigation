extract_chirps_yearly <- function(year, chirps_root, design_points) {
  file_path <- file.path(chirps_root, glue::glue("chirps-v2.0.{year}.days_p05.nc"))

  if (!file.exists(file_path)) {
    stop("File `", file_path, "` does not exist")
  }

  r <- terra::rast(file_path)

  # Set proper georeferencing: CHIRPS is 0.05 deg resolution, global lon: -180 to 180, lat: -50 to 50
  terra::ext(r) <- c(-180, 180, -50, 50)
  terra::crs(r) <- "EPSG:4326"

  pts <- as.matrix(design_points[, c("lon", "lat")])

  vals <- terra::extract(r, pts)
  # Remove ID column (first column) - remaining columns are daily precipitation values
  vals <- vals[, -1, drop = FALSE]
  n_data_cols <- ncol(vals)

  start_date <- as.Date(glue::glue("{year}-01-01"))
  dates <- seq(start_date, by = "day", length.out = n_data_cols)

  results <- purrr::map(seq_len(nrow(design_points)), function(i) {
    tibble::tibble(
      date = dates,
      location_id = design_points$location_id[i],
      precip_mm_day = as.numeric(vals[i, ])
    )
  })

  results |>
    purrr::list_rbind()
}

combine_chirps_results <- function(yearly_results) {
  # When targets combines pattern results, it returns a single data frame
  # if all branches return data frames of the same type
  if (is.data.frame(yearly_results)) {
    return(yearly_results)
  }

  # Handle case where results are a list (e.g., with NULL values that were filtered)
  valid_results <- yearly_results |>
    purrr::keep(~ !is.null(.x))

  if (length(valid_results) == 0) {
    return(tibble::tibble(
      date = as.Date(character()),
      location_id = character(),
      precip_mm_day = numeric()
    ))
  }

  valid_results |>
    purrr::list_rbind()
}
