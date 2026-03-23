#' Import Pre-processed (Curated) Data
#'
#' Imports a pre-processed CSV containing growth parameters already calculated
#' externally. Expected columns: \code{Consortia}, \code{LogPhase}, \code{NGen}, \code{GR}, plus
#' strain presence/absence columns matching \code{cepas_seleccionadas}.
#'
#' @param .Object A \linkS4class{bsocial} object with \code{datos_crudos$curated} populated.
#' @return The modified \linkS4class{bsocial} object with \code{datos_procesados} populated.
#'
#' @export
setMethod("transform_curated_data", "bsocial", function(.Object) {
  bsocial_log("INFO", "transform_curated_data()")

  curated <- .Object@datos_crudos$curated
  cons    <- .Object@datos_crudos$consortia

  if (is.null(curated) || !is.data.frame(curated) || nrow(curated) == 0) {
    stop("Processed (curated) data file not found.")
  }
  if (is.null(cons) || !is.data.frame(cons) || nrow(cons) == 0) {
    stop("consortia.csv not found (required for presence/absence data).")
  }

  if (!"Consortia" %in% colnames(cons)) colnames(cons)[1] <- "Consortia"
  if (!"Consortia" %in% colnames(curated)) colnames(curated)[1] <- "Consortia"

  cons$Consortia <- trimws(as.character(cons$Consortia))
  curated$Consortia <- trimws(as.character(curated$Consortia))

  # Renombrado tolerante
  nm <- colnames(curated)
  lower <- tolower(nm)

  rename_if_present <- function(from, to) {
    pos <- which(lower == tolower(from))
    if (length(pos) == 1) nm[pos] <<- to
  }

  rename_if_present("logphase", "LogPhase")
  rename_if_present("log_phase", "LogPhase")
  rename_if_present("ngen", "NGen")
  rename_if_present("gr", "GR")

  colnames(curated) <- nm

  required <- c("Consortia", "LogPhase", "NGen", "GR")
  missing <- setdiff(required, colnames(curated))
  if (length(missing) > 0) {
    stop("Curated data: missing required columns: ", paste(missing, collapse = ", "))
  }

  curated$LogPhase <- suppressWarnings(as.numeric(curated$LogPhase))
  curated$NGen <- suppressWarnings(as.numeric(curated$NGen))
  curated$GR <- suppressWarnings(as.numeric(curated$GR))

  # Mantener solo métricas (evita colisiones si curated ya trae cepas)
  curated2 <- curated[, c("Consortia", "LogPhase", "NGen", "GR"), drop = FALSE]

  final_df <- dplyr::left_join(cons, curated2, by = "Consortia")

  if (!"group_id" %in% colnames(final_df)) final_df$group_id <- NA

  cols_keep <- c("Consortia", "group_id", .Object@cepas_seleccionadas, "LogPhase", "NGen", "GR")
  cols_keep <- cols_keep[cols_keep %in% colnames(final_df)]
  final_df <- final_df[, cols_keep, drop = FALSE]

  .Object@datos_procesados <- final_df
  .Object
})
