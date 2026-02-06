#' Create SIPNET event files from water balance data
#' 
#' Aggregates irrigation to weekly values and formats for SIPNET.
#' Irrigation is summed by week and reported on the first day of each week.
#' Units are converted from mm to cm.
#'
#' @param df Data frame with columns: date, location_id, year, week, day_of_year, irr
#' @return Data frame with columns: loc, year, doy, event_type, irr_cm, type
#' @export
create_event_file <- function(df) {
  requireNamespace("dplyr", quietly = TRUE)
  
  event_df <- df %>%
    dplyr::group_by(location_id, year, week) %>%
    dplyr::summarize(
      loc = 0,
      year = first(year),
      doy = first(day_of_year),
      event_type = "irrig",
      irr_mm_week = sum(irr, na.rm = TRUE),
      type = 1,
      .groups = "drop"
    )
  
  event_df$irr_cm <- event_df$irr_mm_week / 10
  
  event_df <- event_df[, c("loc", "year", "doy", "event_type", "irr_cm", "type")]
  
  event_df
}
