#!/usr/bin/env Rscript
# Benchmark script comparing local vs. remote CHIRPS data extraction
# Uses /vsicurl GDAL virtual file system for remote access

suppressPackageStartupMessages({
  library(terra)
  library(tibble)
  library(glue)
})

# Configuration
CHIRPS_LOCAL_ROOT <- path.expand("~/data/CHIRPS")
CHIRPS_REMOTE_ROOT <- "https://data.chc.ucsb.edu/products/CHIRPS-2.0/global_daily/netcdf/p05"

# Scan available local CHIRPS data
message("Scanning available local CHIRPS data...")

chirps_files <- list.files(CHIRPS_LOCAL_ROOT, pattern = "chirps-v2\\.0\\.\\d{4}\\.days_p05\\.nc$",
                            full.names = FALSE)
chirps_years <- as.numeric(gsub("chirps-v2\\.0\\.(\\d{4})\\.days_p05\\.nc", "\\1", chirps_files))

message(glue::glue("Found CHIRPS data for years: {paste(sort(chirps_years), collapse = ', ')}"))

# Select test year (use 2024 - complete year)
TEST_YEAR <- 2024
TEST_DAY_OF_YEAR <- 152  # June 1st
TEST_DATE <- as.Date(glue::glue("{TEST_YEAR}-{TEST_DAY_OF_YEAR}"), format = "%Y-%j")
message(glue::glue("Selected test date: {TEST_DATE} (day {TEST_DAY_OF_YEAR} of {TEST_YEAR})"))

# Load design points
design_points <- read.csv("design_points.csv", stringsAsFactors = FALSE)
colnames(design_points) <- c("location_id", "lat", "lon")
message(glue::glue("Loaded {nrow(design_points)} design points\n"))

# Function to extract CHIRPS data (local) for a specific date
extract_chirps_local <- function(year, day_of_year, design_points) {
  file_path <- file.path(CHIRPS_LOCAL_ROOT, glue::glue("chirps-v2.0.{year}.days_p05.nc"))
  
  if (!file.exists(file_path)) {
    stop("Local file `", file_path, "` does not exist")
  }
  
  r <- terra::rast(file_path)
  terra::ext(r) <- c(-180, 180, -50, 50)
  terra::crs(r) <- "EPSG:4326"
  
  # Extract only the specific day of year
  r_day <- r[[day_of_year]]
  
  pts <- as.matrix(design_points[, c("lon", "lat")])
  vals <- terra::extract(r_day, pts)
  
  date <- as.Date(glue::glue("{year}-{day_of_year}"), format = "%Y-%j")
  
  tibble::tibble(
    date = date,
    location_id = design_points$location_id,
    precip_mm_day = as.numeric(vals[, 1])
  )
}

# Function to extract CHIRPS data (remote via /vsicurl) for a specific date
extract_chirps_remote <- function(year, day_of_year, design_points) {
  url <- glue::glue("{CHIRPS_REMOTE_ROOT}/chirps-v2.0.{year}.days_p05.nc")
  vsicurl_path <- paste0("/vsicurl/", url)
  
  r <- terra::rast(vsicurl_path)
  terra::ext(r) <- c(-180, 180, -50, 50)
  terra::crs(r) <- "EPSG:4326"
  
  # Extract only the specific day of year
  r_day <- r[[day_of_year]]
  
  pts <- as.matrix(design_points[, c("lon", "lat")])
  vals <- terra::extract(r_day, pts)
  
  date <- as.Date(glue::glue("{year}-{day_of_year}"), format = "%Y-%j")
  
  tibble::tibble(
    date = date,
    location_id = design_points$location_id,
    precip_mm_day = as.numeric(vals[, 1])
  )
}

# Benchmark function
run_benchmark <- function(name, fn, ...) {
  message(glue::glue("--- {name} ---"))
  start_time <- Sys.time()
  
  result <- tryCatch({
    fn(...)
  }, error = function(e) {
    message(glue::glue("ERROR: {e$message}"))
    NULL
  })
  
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
message("CHIRPS: Local vs Remote Benchmark")
message("========================================")
message(glue::glue("Test date: {TEST_DATE}"))
message(glue::glue("Number of locations: {nrow(design_points)}\n"))

# Test CHIRPS local
chirps_local <- run_benchmark("CHIRPS - Local", extract_chirps_local, TEST_YEAR, TEST_DAY_OF_YEAR, design_points)

# Test CHIRPS remote
chirps_remote <- run_benchmark("CHIRPS - Remote", extract_chirps_remote, TEST_YEAR, TEST_DAY_OF_YEAR, design_points)

# Summary
message("\n========================================")
message("BENCHMARK SUMMARY")
message("========================================")

results_df <- tibble::tibble(
  Access_Type = c("Local", "Remote"),
  Time_Seconds = c(chirps_local$time, chirps_remote$time),
  Success = c(chirps_local$success, chirps_remote$success)
)

if (chirps_local$success && chirps_remote$success) {
  results_df$Factor <- c(1.0, chirps_remote$time / chirps_local$time)
} else {
  results_df$Factor <- c(1.0, NA)
}

print(results_df, n = Inf)

# Compare data values (if both succeeded)
if (chirps_local$success && chirps_remote$success) {
  message("\n--- Data Comparison ---")
  chirps_diff <- max(abs(chirps_local$result$precip_mm_day - chirps_remote$result$precip_mm_day), na.rm = TRUE)
  message(glue::glue("Maximum difference in precip values: {round(chirps_diff, 6)} mm/day"))
}

message("\n========================================")
message("CHIRPS Benchmark complete!")
message("========================================")
