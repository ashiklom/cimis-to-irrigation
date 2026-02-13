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

extract_openet_daily <- function(start_date, end_date, design_points) {
  api_key <- Sys.getenv("OPENET_API_KEY")
  if (api_key == "") {
    stop("OPENET_API_KEY environment variable is not set")
  }

  start_date_str <- format(start_date, "%Y-%m-%d")
  end_date_str <- format(end_date, "%Y-%m-%d")

  request_body_template <- list(
    date_range = c(start_date_str, end_date_str),
    interval = "daily",
    model = "Ensemble",
    variable = "ET",
    reference_et = "gridMET",
    units = "mm",
    file_format = "JSON"
  )

  reqs <- purrr::map(seq_len(nrow(design_points)), function(i) {
    pt <- design_points[i, ]
    request_body <- request_body_template
    request_body$geometry <- c(pt$lon, pt$lat)

    httr2::request("https://openet-api.org/raster/timeseries/point") |>
      httr2::req_headers(Authorization = api_key) |>
      httr2::req_body_json(request_body) |>
      httr2::req_throttle(capacity = 10, fill_time_s = 1) |>
      httr2::req_retry(max_tries = 3) |>
      httr2::req_timeout(seconds = 150)
  })

  resps <- httr2::req_perform_parallel(
    reqs,
    max_active = 10,
    on_error = "continue"
  )

  results <- purrr::map_dfr(seq_len(nrow(design_points)), function(i) {
    pt <- design_points[i, ]
    resp <- resps[[i]]

    if (inherits(resp, "httr2_response")) {
      # Result is a list of lists like:
      # list(list(time=..., et=...), list(time=..., et=...), ...)
      data <- httr2::resp_body_json(resp)

      if (length(data) > 0 && !is.null(data[[1]]$time)) {
        tibble::tibble(
          date = purrr::map_chr(data, "time") |> as.Date(),
          location_id = pt$location_id,
          et_mm_day = purrr::map_dbl(data, "et")
        )
      } else {
        tibble::tibble(
          date = as.Date(NULL),
          location_id = character(),
          et_mm_day = numeric()
        )
      }
    } else {
      tibble::tibble(
        date = as.Date(NULL),
        location_id = character(),
        et_mm_day = numeric()
      )
    }
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
