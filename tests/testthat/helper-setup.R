# Shared test fixtures

#' Create a bsocial object loaded with curated example data
create_curated_test_object <- function() {
  obj <- new("bsocial")

  consortia_path <- system.file("extdata", "consortia.csv", package = "bsocial")
  curated_path <- system.file("extdata", "curated_MTBE.csv", package = "bsocial")

  consortia <- readr::read_csv(consortia_path, show_col_types = FALSE)
  curated <- readr::read_csv(curated_path, show_col_types = FALSE)

  strain_cols <- setdiff(colnames(consortia), "Consortia")
  obj@cepas_seleccionadas <- strain_cols
  obj@datos_crudos <- list(
    consortia = as.data.frame(consortia),
    curated = as.data.frame(curated),
    type = "curated"
  )

  obj
}

#' Create a bsocial object loaded with raw example data
create_raw_test_object <- function() {
  obj <- new("bsocial")

  consortia_path <- system.file("extdata", "consortia.csv", package = "bsocial")
  consortia <- readr::read_csv(consortia_path, show_col_types = FALSE)

  plates <- list()
  for (i in 1:6) {
    plate_path <- system.file("extdata", paste0("plate", i, ".csv"), package = "bsocial")
    if (file.exists(plate_path) && nchar(plate_path) > 0) {
      # Read header to extract time column names (skip first 4 metadata cols)
      first_line <- readLines(plate_path, n = 1)
      header_parts <- strsplit(first_line, ",")[[1]]
      # Remove surrounding quotes from header parts
      header_parts <- gsub('^"(.*)"$', "\\1", header_parts)
      time_strings <- header_parts[-c(1:4)]
      time_values <- as.numeric(time_strings)
      valid_time <- !is.na(time_values)
      time_values <- time_values[valid_time]

      # Read data (skip header row)
      df <- read.csv(plate_path, header = FALSE, skip = 1,
                     stringsAsFactors = FALSE, check.names = FALSE)

      # Select metadata + valid time columns
      data_cols <- c(1:4, which(valid_time) + 4)
      data_cols <- data_cols[data_cols <= ncol(df)]
      df <- df[, data_cols, drop = FALSE]

      # Assign proper column names: V_ID, WellID, SampleID, PlateID, time...
      colnames(df) <- c("V_ID", "WellID", "SampleID", "PlateID",
                         as.character(time_values))

      # Keep only WellID, SampleID, and time columns (what transform_raw_data expects)
      time_col_names <- as.character(time_values)
      plates[[i]] <- data.frame(
        WellID   = trimws(as.character(df$WellID)),
        SampleID = trimws(as.character(df$SampleID)),
        df[, time_col_names, drop = FALSE],
        stringsAsFactors = FALSE,
        check.names = FALSE
      )
    }
  }

  # Truncate all plates to common time columns (plates may differ in length)
  time_col_sets <- lapply(plates, function(p) {
    setdiff(colnames(p), c("WellID", "SampleID"))
  })
  common_times <- Reduce(intersect, time_col_sets)
  plates <- lapply(plates, function(p) {
    p[, c("WellID", "SampleID", common_times), drop = FALSE]
  })

  strain_cols <- setdiff(colnames(consortia), "Consortia")
  obj@cepas_seleccionadas <- strain_cols
  obj@datos_crudos <- list(
    consortia = as.data.frame(consortia),
    plates = plates,
    type = "raw"
  )

  obj
}
