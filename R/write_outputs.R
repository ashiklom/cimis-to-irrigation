#' Write per-site outputs (water balance CSV and event file)
#'
#' @param df Data frame with water balance results
#' @param output_dir Output directory path
#' @return List of written file paths
#' @export
write_all_outputs <- function(df, output_dir) {
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  sites <- split(df, df$location_id)

  written_files <- purrr::map(names(sites), function(loc_id) {
    site_df <- sites[[loc_id]]

    csv_path <- file.path(output_dir, glue::glue("{loc_id}_water_balance.csv"))

    csv_df <- site_df |>
      dplyr::select(
        time = "date",
        et = "et_mm_day",
        precip = "precip_mm_day",
        "W_t",
        "irr",
        "runoff",
        "year",
        "week",
        "day_of_year"
      ) |>
      dplyr::mutate(time = as.character(time))

    readr::write_csv(csv_df, csv_path)

    event_path <- file.path(output_dir, glue::glue("{loc_id}_events.txt"))
    event_df <- create_event_file(site_df) #nolint

    readr::write_delim(
      event_df,
      event_path,
      delim = " ",
      col_names = FALSE
    )

    list(csv = csv_path, event = event_path)
  })

  written_files |>
    purrr::list_c() |>
    unname()
}
