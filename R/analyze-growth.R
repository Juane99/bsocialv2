#' Analyze Growth Metrics
#'
#' Creates a scatter plot of LogPhase vs NGen colored by consortium diversity,
#' and generates top-10 tables ranked by NGen and GR.
#'
#' @param .Object A \linkS4class{bsocial} object with \code{datos_procesados} populated.
#' @return The modified \linkS4class{bsocial} object with growth analysis in \code{graficos} and \code{resultados_analisis}.
#'
#' @export
setMethod("analyze_growth", "bsocial", function(.Object) {
  bsocial_log("INFO", "analyze_growth()")

  df <- .Object@datos_procesados
  if (is.null(df) || nrow(df) == 0) {
    stop("No processed data. Run calculate_growth_params() or transform_curated_data() first.")
  }

  required <- c("LogPhase", "NGen", "GR")
  missing <- setdiff(required, colnames(df))
  if (length(missing) > 0) {
    stop("Missing required columns in processed data: ", paste(missing, collapse = ", "))
  }

  strains <- .Object@cepas_seleccionadas
  if (!all(strains %in% colnames(df))) {
    stop("Strain columns missing in processed data.")
  }

  .Object@graficos$growth_scatter <- plot_growth_scatter(.Object, remove_outliers = FALSE)

  keep_cols <- intersect(c("Consortia", "group_id", "LogPhase", "NGen", "GR"), colnames(df))
  df2 <- df[, keep_cols, drop = FALSE]

  ord_ngen <- order(df2$NGen, df2$LogPhase, decreasing = TRUE, na.last = TRUE)
  ord_gr   <- order(df2$GR, df2$LogPhase, decreasing = TRUE, na.last = TRUE)

  best_10_ngen <- df2[ord_ngen, , drop = FALSE]
  best_10_gr   <- df2[ord_gr,   , drop = FALSE]

  best_10_ngen <- utils::head(best_10_ngen, 10)
  best_10_gr   <- utils::head(best_10_gr, 10)

  .Object@resultados_analisis$best_10_ngen <- best_10_ngen
  .Object@resultados_analisis$best_10_gr   <- best_10_gr
  .Object@resultados_analisis$best_10 <- best_10_ngen

  .Object
})
