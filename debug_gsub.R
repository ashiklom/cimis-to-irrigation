test_file <- "2025/06/01/ETo.asc.gz"
parts <- strsplit(test_file, "/")[[1]]
cat("Parts:", paste(parts, collapse=" | "), "\n")

# Try different approaches
filename <- parts[length(parts)]
cat("Filename:", filename, "\n")

# Using character class for dots
day1 <- gsub("ETo[.]asc[.]gz$", "", filename)
cat("Day (character class):", day1, "\n")

# Using fixed=TRUE
day2 <- gsub("ETo.asc.gz", "", filename, fixed=TRUE)
cat("Day (fixed=TRUE):", day2, "\n")

# Just remove the extension
day3 <- gsub("\\.asc\\.gz$", "", filename)
cat("Day (remove extension):", day3, "\n")
