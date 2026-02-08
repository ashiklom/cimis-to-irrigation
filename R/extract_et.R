extract_cimis_daily <- function(date, cimis_root, design_points) {
  date_str <- format(date, "%Y/%m/%d")
  file_path <- file.path(cimis_root, date_str, "ETo.asc.gz")

  if (!file.exists(file_path)) {
    stop("File `", file_path, "` does not exist")
  }

  r <- terra::rast(paste0("/vsigzip/", file_path))

  terra::crs(r) <- "EPSG:3310"  # California Albers

  pts_sf <- sf::st_as_sf(design_points, coords = c("lon", "lat"), crs = 4326)
  pts_albers <- sf::st_transform(pts_sf, crs = 3310)
  coords <- sf::st_coordinates(pts_albers)

  vals <- terra::extract(r, coords)

  tibble::tibble(
    date = date,
    location_id = design_points$location_id,
    et_mm_day = vals[, 1]
  )
}

combine_cimis_results <- function(daily_results) {
  # When targets combines pattern results, it returns a single data frame
  # if all branches return data frames of the same type
  if (is.data.frame(daily_results)) {
    return(daily_results)
  }

  # Handle case where results are a list (e.g., with NULL values that were filtered)
  valid_results <- daily_results |>
    purrr::keep(~ !is.null(.x))

  if (length(valid_results) == 0) {
    return(tibble::tibble(
      date = as.Date(character()),
      location_id = character(),
      et_mm_day = numeric()
    ))
  }

  valid_results |>
    purrr::list_rbind()
}
