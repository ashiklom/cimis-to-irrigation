#' Calculate water balance using primitive R vectors
#'
#' This is the core water balance calculation that operates on primitive
#' numeric vectors for easy testing and debugging.
#'
#' @param et Vector of evapotranspiration values (mm/day)
#' @param precip Vector of precipitation values (mm/day)
#' @param whc Water holding capacity (mm), default 500
#' @param w_min_frac Fraction of WHC for minimum water level, default 0.15
#' @return List with vectors: W_t (water balance), irr (irrigation), runoff
#' @export
calc_water_balance <- function(et, precip,
                               whc = 500,
                               w_min_frac = 0.15) {
  n <- length(et)
  if (length(precip) != n) {
    stop("et and precip must have the same length")
  }

  w_min <- w_min_frac * whc
  field_capacity <- whc / 2

  W_t <- numeric(n) #nolint: object_name_linter
  W0_t <- numeric(n) #nolint: object_name_linter
  irr <- numeric(n)
  runoff <- numeric(n)

  W_t[1] <- field_capacity #nolint: object_name_linter

  for (t in seq_len(n)) {
    if (t == 1) {
      W_prev <- field_capacity #nolint: object_name_linter
    } else {
      W_prev <- W_t[t - 1] #nolint: object_name_linter
    }

    W0_t[t] <- W_prev + precip[t] - et[t] #nolint: object_name_linter

    irr[t] <- max(w_min - W0_t[t], 0)

    runoff[t] <- max(W0_t[t] - whc, 0)

    W_t[t] <- W_prev + precip[t] + irr[t] - et[t] - runoff[t] #nolint: object_name_linter
  }

  list(
    W_t = W_t,
    irr = irr,
    runoff = runoff
  )
}

#' Apply water balance calculations to a data frame
#'
#' Groups by location and applies calc_water_balance to each group.
#'
#' @param df Data frame with columns: date, location_id, et_mm_day, precip_mm_day
#' @param whc Water holding capacity (mm)
#' @return Data frame with added columns: W_t, irr, runoff
#' @export
apply_water_balance <- function(df, whc = 500) {
  df |>
    dplyr::arrange(.data$location_id, .data$date) |>
    dplyr::mutate(
      year = as.integer(format(.data$date, "%Y")),
      week = as.integer(format(.data$date, "%U")),
      day_of_year = as.integer(format(.data$date, "%j")),
      .by = .data$location_id
    ) |>
    dplyr::group_split(.data$location_id) |>
    purrr::map_dfr(~{
      et <- .x$et_mm_day
      precip <- .x$precip_mm_day

      wb <- calc_water_balance(et, precip, whc = whc)

      .x$W_t <- wb$W_t
      .x$irr <- wb$irr
      .x$runoff <- wb$runoff

      .x
    })
}

.data <- rlang::.data
