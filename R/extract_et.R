extract_cimis_daily <- function(date, local_root_dir = NA, design_points) {
  date_str <- format(date, "%Y/%m/%d")

  if (is.na(local_root_dir)) {
    # Read from remote using /vsicurl
    base_url <- "https://spatialcimis.water.ca.gov/cimis"
    file_path <- file.path(base_url, date_str, "ETo.asc.gz")
    vsicurl_path <- paste0("/vsigzip//vsicurl/", file_path)
  } else {
    # Read from local copy
    file_path <- file.path(local_root_dir, date_str, "ETo.asc.gz")
    vsicurl_path <- paste0("/vsigzip/", file_path)

    if (!file.exists(file_path)) {
      stop("File `", file_path, "` does not exist")
    }
  }

  r <- terra::rast(vsicurl_path)

  terra::crs(r) <- "EPSG:3310" # California Albers

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

extract_openet_daily <- function(date, design_points) {
  api_key <- Sys.getenv("OPENET_API_KEY")
  if (api_key == "") {
    stop("OPENET_API_KEY environment variable is not set")
  }

  # Format date for API
  date_str <- format(date, "%Y-%m-%d")

  # Prepare request body
  request_body <- list(
    date_range = c(date_str, date_str),
    interval = "daily",
    model = "Ensemble",
    variable = "ET",
    reference_et = "gridMET",
    units = "mm",
    file_format = "JSON"
  )

  # Make API requests for each design point
  results <- purrr::map_dfr(seq_len(nrow(design_points)), function(i) {
    pt <- design_points[i, ]
    request_body$geometry <- c(pt$lon, pt$lat)

    resp <- httr2::request("https://openet-api.org/raster/timeseries/point") |>
      httr2::req_headers(Authorization = api_key) |>
      httr2::req_body_json(request_body) |>
      httr2::req_retry(max_tries = 3) |>
      httr2::req_timeout(seconds = 30) |>
      httr2::req_perform()

    # Parse response
    data <- httr2::resp_body_json(resp)

    # The API returns a list with time series data
    # Extract the ET value for the requested date
    if (length(data) > 0 && !is.null(data[[1]]$time)) {
      # Find the entry for our date
      et_value <- purrr::detect(data, ~ .$time == date_str)$et
      if (is.null(et_value)) {
        et_value <- NA_real_
      }
    } else {
      et_value <- NA_real_
    }

    tibble::tibble(
      date = date,
      location_id = pt$location_id,
      et_mm_day = et_value
    )
  })

  results
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
