library(targets)

tar_option_set(
  packages = c("terra", "sf", "dplyr", "readr", "purrr", "glue", "tibble"),
  format = "qs"
)

tar_source()

cimis_root <- path.expand(Sys.getenv("CIMIS_ROOT", "~/data/CIMIS_raw"))
chirps_root <- path.expand(Sys.getenv("CHIRPS_ROOT", "~/data/CHIRPS"))
output_dir <- "_outputs"

list(
  tar_target(
    design_points,
    read_design_points("design_points.csv")
  ),

  tar_target(
    cimis_dates,
    discover_cimis_dates(cimis_root)
  ),

  tar_target(
    chirps_years,
    discover_chirps_years(chirps_root)
  ),

  tar_target(
    cimis_et_daily,
    extract_cimis_daily(cimis_dates, cimis_root, design_points),
    pattern = map(cimis_dates)
  ),

  tar_target(
    cimis_et_long,
    combine_cimis_results(cimis_et_daily)
  ),

  tar_target(
    chirps_precip_yearly,
    extract_chirps_yearly(chirps_years, chirps_root, design_points),
    pattern = map(chirps_years)
  ),

  tar_target(
    chirps_precip_long,
    combine_chirps_results(chirps_precip_yearly)
  ),

  tar_target(
    merged_data,
    dplyr::full_join(
      cimis_et_long,
      chirps_precip_long,
      by = c("date", "location_id")
    ) |>
      dplyr::filter(!is.na(et_mm_day), !is.na(precip_mm_day))
  ),

  tar_target(
    water_balance_results,
    apply_water_balance(merged_data, whc = 500)
  ),

  tar_target(
    output_files,
    write_all_outputs(water_balance_results, output_dir)
  )
)
