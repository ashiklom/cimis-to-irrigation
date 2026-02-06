extract_cimis_daily <- function(date, cimis_root, design_points) {
  requireNamespace("terra", quietly = TRUE)
  requireNamespace("sf", quietly = TRUE)
  
  date_str <- format(date, "%Y/%m/%d")
  file_path <- file.path(cimis_root, date_str, "ETo.asc.gz")
  
  if (!file.exists(file_path)) {
    return(NULL)
  }
  
  r <- terra::rast(paste0("/vsigzip/", file_path))
  
  terra::crs(r) <- "EPSG:3310"  # California Albers
  
  pts_sf <- sf::st_as_sf(design_points, coords = c("lon", "lat"), crs = 4326)
  pts_albers <- sf::st_transform(pts_sf, crs = 3310)
  coords <- sf::st_coordinates(pts_albers)
  
  vals <- terra::extract(r, coords)
  
  data.frame(
    date = date,
    location_id = design_points$location_id,
    et_mm_day = vals[, 1],
    stringsAsFactors = FALSE
  )
}

combine_cimis_results <- function(daily_results) {
  requireNamespace("dplyr", quietly = TRUE)
  valid_results <- Filter(Negate(is.null), daily_results)
  if (length(valid_results) == 0) {
    return(data.frame(
      date = as.Date(character()),
      location_id = character(),
      et_mm_day = numeric(),
      stringsAsFactors = FALSE
    ))
  }
  dplyr::bind_rows(valid_results)
}
