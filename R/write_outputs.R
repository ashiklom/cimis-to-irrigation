#' Write per-site outputs (water balance CSV and event file)
#' 
#' @param df Data frame with water balance results
#' @param output_dir Output directory path
#' @return List of written file paths
#' @export
write_all_outputs <- function(df, output_dir) {
  requireNamespace("dplyr", quietly = TRUE)
  
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }
  
  sites <- split(df, df$location_id)
  
  written_files <- lapply(names(sites), function(loc_id) {
    site_df <- sites[[loc_id]]
    
    csv_path <- file.path(output_dir, paste0(loc_id, "_water_balance.csv"))
    
    csv_df <- site_df[, c("date", "et_mm_day", "precip_mm_day", "W_t", "irr", "runoff", "year", "week", "day_of_year")]
    colnames(csv_df) <- c("time", "et", "precip", "W_t", "irr", "runoff", "year", "week", "day_of_year")
    csv_df$time <- as.character(csv_df$time)
    
    write.csv(csv_df, csv_path, row.names = FALSE)
    
    event_path <- file.path(output_dir, paste0(loc_id, "_events.txt"))
    event_df <- create_event_file(site_df)
    
    write.table(event_df, event_path, 
                row.names = FALSE, 
                col.names = FALSE, 
                sep = " ",
                quote = FALSE)
    
    c(csv = csv_path, event = event_path)
  })
  
  unlist(written_files, use.names = FALSE)
}
