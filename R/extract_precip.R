extract_chirps_yearly <- function(year, chirps_root, design_points) {
  requireNamespace("terra", quietly = TRUE)
  
  file_path <- file.path(chirps_root, sprintf("chirps-v2.0.%d.days_p05.nc", year))
  
  if (!file.exists(file_path)) {
    return(NULL)
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
  
  start_date <- as.Date(sprintf("%d-01-01", year))
  dates <- seq(start_date, by = "day", length.out = n_data_cols)
  
  results <- lapply(seq_len(nrow(design_points)), function(i) {
    data.frame(
      date = dates,
      location_id = design_points$location_id[i],
      precip_mm_day = as.numeric(vals[i, ]),
      stringsAsFactors = FALSE
    )
  })
  
  do.call(rbind, results)
}

combine_chirps_results <- function(yearly_results) {
  requireNamespace("dplyr", quietly = TRUE)
  valid_results <- Filter(Negate(is.null), yearly_results)
  if (length(valid_results) == 0) {
    return(data.frame(
      date = as.Date(character()),
      location_id = character(),
      precip_mm_day = numeric(),
      stringsAsFactors = FALSE
    ))
  }
  dplyr::bind_rows(valid_results)
}
