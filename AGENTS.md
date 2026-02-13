# Agent instructions

## Dependency management:

This project uses the `pixi` package manager. Always attempt to install R packages using pixi first (e.g., to install `dplyr`, use `pixi add r-dplyr`); only fall back to `install.packages` if that fails. Ask before installing new packages. To see current project dependencies, refer to the `pixi.toml`. To see the full list of available libraries and their versions, see `pixi.lock`.

Run all R scripts, GDAL commands, etc. with `pixi run`  (e.g., `pixi run Rscript <script.R>`; `pixi run gdalinfo`).

## External data locations

For the purposes of local development, sample subsets of relevant data are located in `~/data`; specifically:

- CIMIS --- `~/data/CIMIS_raw`, in subdirectories year, month, day (`YYYY/MM/DD`). The ET data you need for CIMIS are in the `ET.asc.gz` file.
    - It should be possible to open the data directly with GDAL (and GDAL-based tools like R's `terra` package) using the `/vsigzip` virtual driver; e.g., `gdalinfo /vsigzip//~/data/CIMIS_raw/2025/12/01/ETo.asc.gz`. Assume this data is in California Albers (EPSG: 3310).
- CHIRPS --- `~/data/CHIRPS`. Data are daily, one file per year (e.g., `~/data/CHIRPS/chirps-v2.0.2024.days_p05.nc`), in NetCDF format. An example NetCDF header is provided in the `README.md`.

The root directories for all of these datasets should be configurable --- by either command line arguments or a simple configuration file (that R can read without external dependencies).

## Implementation

Use the R `targets` package to organize this workflow.
Follow targets best practices -- in particular, write functions and put them in the `R/` directory.

This workflow will eventually run on an HPC using Sun Grid Engine (SGE); `qsub`, etc. commands for job submission.
Prefer simple, single process tasks and local execution.
However, the workflow seems too big for local processing, plan on using targets + crew for execution on multiple HPC nodes.

## httr2 Parallel Requests

When making multiple API calls (e.g., to OpenET), use httr2's built-in parallel request capabilities:

### Key Functions

- **`req_perform_parallel(reqs, max_active = 10, on_error = "stop")`** - Perform multiple requests in parallel
  - `reqs`: A list of httr2 request objects
  - `max_active`: Maximum concurrent requests (default 10)
  - `on_error`: "stop" (default), "return" (return all with errors), or "continue"

- **`req_throttle(capacity, fill_time_s)`** - Rate limiting to avoid overwhelming servers
  - `capacity`: Number of requests allowed per time period
  - `fill_time_s`: Time in seconds for the bucket to refill

### Example Pattern

```r
# Build request templates
reqs <- purrr::map(seq_len(nrow(design_points)), function(i) {
  pt <- design_points[i, ]
  request_body$geometry <- c(pt$lon, pt$lat)

  httr2::request("https://api.example.org/endpoint") |>
    httr2::req_headers(Authorization = api_key) |>
    httr2::req_body_json(request_body) |>
    httr2::req_throttle(capacity = 10, fill_time_s = 1) |>
    httr2::req_retry(max_tries = 3) |>
    httr2::req_timeout(seconds = 30)
})

# Execute in parallel
resps <- httr2::req_perform_parallel(reqs, max_active = 10, on_error = "continue")

# Process responses
results <- purrr::map_dfr(resps, function(resp) {
  if (inherits(resp, "httr2_response")) {
    data <- httr2::resp_body_json(resp)
    # Process data...
  } else {
    # Handle error
    tibble::tibble(et_mm_day = NA_real_)
  }
})
```

### Best Practices

1. Always use `req_throttle()` with parallel requests
2. Use `on_error = "continue"` to handle partial failures gracefully
3. Check response class before processing (errors will be error objects, not response objects)
