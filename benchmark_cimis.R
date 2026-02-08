#!/usr/bin/env Rscript
# Benchmark script comparing local vs. remote CIMIS data extraction
# Uses /vsicurl GDAL virtual file system for remote access

suppressPackageStartupMessages({
  library(terra)
  library(sf)
  library(tibble)
  library(glue)
})

# Configuration
CIMIS_LOCAL_ROOT <- path.expand("~/data/CIMIS_raw")
CIMIS_REMOTE_ROOT <- "https://spatialcimis.water.ca.gov/cimis"

# Scan available local CIMIS data
message("Scanning available local CIMIS data...")

cimis_files <- list.files(
  CIMIS_LOCAL_ROOT,
  pattern = "ETo\\.asc\\.gz$",
  recursive = TRUE,
  full.names = TRUE
)
cimis_dates <- gsub(
  ".*(\\d{4})/(\\d{2})/(\\d{2})/ETo\\.asc\\.gz$",
  "\\1-\\2-\\3",
  cimis_files
)
cimis_dates <- as.Date(cimis_dates, format = "%Y-%m-%d")
cimis_dates <- cimis_dates[!is.na(cimis_dates)]

message(glue::glue("Found {length(cimis_dates)} CIMIS daily files"))
message(glue::glue("Date range: {min(cimis_dates)} to {max(cimis_dates)}"))

# Select test date (use first available)
TEST_DATE <- cimis_dates[1]
message(glue::glue("\nSelected test date: {TEST_DATE}"))

# Load design points
design_points <- read.csv("design_points.csv", stringsAsFactors = FALSE)
colnames(design_points) <- c("location_id", "lat", "lon")
message(glue::glue("Loaded {nrow(design_points)} design points\n"))

# Function to extract CIMIS data (local)
extract_cimis_local <- function(date, design_points) {
  date_str <- format(date, "%Y/%m/%d")
  file_path <- file.path(CIMIS_LOCAL_ROOT, date_str, "ETo.asc.gz")

  if (!file.exists(file_path)) {
    stop("Local file `", file_path, "` does not exist")
  }

  r <- terra::rast(paste0("/vsigzip/", file_path))
  terra::crs(r) <- "EPSG:3310"

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

# Function to extract CIMIS data (remote via /vsicurl)
extract_cimis_remote <- function(date, design_points) {
  date_str <- format(date, "%Y/%m/%d")
  url <- glue::glue("{CIMIS_REMOTE_ROOT}/{date_str}/ETo.asc.gz")
  vsicurl_path <- paste0("/vsigzip//vsicurl/", url)

  r <- terra::rast(vsicurl_path)
  terra::crs(r) <- "EPSG:3310"

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

# Benchmark function
run_benchmark <- function(name, fn, ...) {
  message(glue::glue("--- {name} ---"))
  start_time <- Sys.time()

  result <- tryCatch(
    {
      fn(...)
    },
    error = function(e) {
      message(glue::glue("ERROR: {e$message}"))
      NULL
    }
  )

  end_time <- Sys.time()
  elapsed <- as.numeric(difftime(end_time, start_time, units = "secs"))

  if (!is.null(result)) {
    message(glue::glue("Success: {nrow(result)} rows extracted"))
    message(glue::glue("Time elapsed: {round(elapsed, 2)} seconds"))
  } else {
    message(glue::glue("Failed after: {round(elapsed, 2)} seconds"))
  }

  invisible(list(result = result, time = elapsed, success = !is.null(result)))
}

# Run benchmarks
message("========================================")
message("CIMIS: Local vs Remote Benchmark")
message("========================================")
message(glue::glue("Test date: {TEST_DATE}"))
message(glue::glue("Number of locations: {nrow(design_points)}\n"))

# Test CIMIS local
cimis_local <- run_benchmark(
  "CIMIS - Local",
  extract_cimis_local,
  TEST_DATE,
  design_points
)

# Test CIMIS remote
cimis_remote <- run_benchmark(
  "CIMIS - Remote",
  extract_cimis_remote,
  TEST_DATE,
  design_points
)

# Summary
message("\n========================================")
message("BENCHMARK SUMMARY")
message("========================================")

results_df <- tibble::tibble(
  Access_Type = c("Local", "Remote"),
  Time_Seconds = c(cimis_local$time, cimis_remote$time),
  Success = c(cimis_local$success, cimis_remote$success)
)

if (cimis_local$success && cimis_remote$success) {
  results_df$Factor <- c(1.0, cimis_remote$time / cimis_local$time)
} else {
  results_df$Factor <- c(1.0, NA)
}

print(results_df, n = Inf)

# Compare data values (if both succeeded)
if (cimis_local$success && cimis_remote$success) {
  message("\n--- Data Comparison ---")
  cimis_diff <- max(
    abs(cimis_local$result$et_mm_day - cimis_remote$result$et_mm_day),
    na.rm = TRUE
  )
  message(glue::glue(
    "Maximum difference in ET values: {round(cimis_diff, 6)} mm/day"
  ))
}

message("\n========================================")
message("CIMIS Benchmark complete!")
message("========================================")
