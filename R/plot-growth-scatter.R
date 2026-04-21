#' Plot Growth Scatter (LogPhase vs NGen)
#'
#' Renders the scatter of LogPhase against Number of Generations coloured by
#' consortium richness, with optional IQR-based outlier hiding for
#' visualization. The underlying \code{datos_procesados} is not modified.
#'
#' @param .Object A \linkS4class{bsocial} object with \code{datos_procesados} populated.
#' @param remove_outliers Logical; if \code{TRUE}, hides points where LogPhase or NGen
#'   fall above the Q3 + coef * IQR threshold (Tukey boxplot rule).
#' @param outlier_coef Numeric multiplier for the IQR rule (default 1.5).
#' @return A ggplot2 object.
#' @importFrom stats quantile
#' @export
setGeneric("plot_growth_scatter", function(.Object, remove_outliers = FALSE, outlier_coef = 1.5) {
  standardGeneric("plot_growth_scatter")
})

#' @rdname plot_growth_scatter
#' @export
setMethod("plot_growth_scatter", "bsocial", function(.Object, remove_outliers = FALSE, outlier_coef = 1.5) {
  df <- .Object@datos_procesados
  if (is.null(df) || nrow(df) == 0) {
    stop("No processed data. Run calculate_growth_params() or transform_curated_data() first.")
  }

  required <- c("LogPhase", "NGen")
  missing <- setdiff(required, colnames(df))
  if (length(missing) > 0) {
    stop("Missing required columns in processed data: ", paste(missing, collapse = ", "))
  }

  strains <- .Object@cepas_seleccionadas
  if (!all(strains %in% colnames(df))) {
    stop("Strain columns missing in processed data.")
  }

  df$n_cepas <- rowSums(!is.na(df[, strains, drop = FALSE]))

  hidden_subtitle <- NULL
  if (isTRUE(remove_outliers)) {
    q_lp <- stats::quantile(df$LogPhase, c(0.25, 0.75), na.rm = TRUE)
    q_ng <- stats::quantile(df$NGen,     c(0.25, 0.75), na.rm = TRUE)
    thr_lp <- q_lp[2] + outlier_coef * diff(q_lp)
    thr_ng <- q_ng[2] + outlier_coef * diff(q_ng)

    keep <- (is.na(df$LogPhase) | df$LogPhase <= thr_lp) &
            (is.na(df$NGen)     | df$NGen     <= thr_ng)
    hidden <- sum(!keep, na.rm = TRUE)
    df <- df[keep, , drop = FALSE]
    hidden_subtitle <- sprintf("%d consortia hidden (IQR rule, coef=%.2f)", hidden, outlier_coef)
  }

  ggplot2::ggplot(df, ggplot2::aes(x = LogPhase, y = NGen, color = factor(n_cepas))) +
    ggplot2::geom_point(size = 3, alpha = 0.8, na.rm = TRUE) +
    ggplot2::labs(
      title    = "Growth: LogPhase vs Number of Generations",
      subtitle = hidden_subtitle,
      x = "Log Phase (h)",
      y = "Number of Generations",
      color = "Num. strains"
    ) +
    ggplot2::theme_minimal()
})
