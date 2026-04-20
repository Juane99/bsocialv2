#' Analyze Diversity Effect on Fitness
#'
#' Analyzes the relationship between consortium diversity (number of strains)
#' and fitness. Computes relative fitness by comparing each consortium's metric
#' against the best monoculture reference.
#'
#' @param .Object A \linkS4class{bsocial} object after \code{analyze_social_behavior()} has been called.
#' @return The modified \linkS4class{bsocial} object with diversity analysis in \code{graficos} and \code{resultados_analisis}.
#'
#' @export
setMethod("analyze_diversity", "bsocial", function(.Object) {
  bsocial_log("INFO", "analyze_diversity()")

  df <- .Object@datos_procesados
  if (is.null(df) || nrow(df) == 0) {
    stop("No processed data available for diversity analysis.")
  }

  strains <- .Object@cepas_seleccionadas
  if (!all(strains %in% colnames(df))) {
    stop("Strain columns missing in processed data.")
  }
  if (!all(c("NGen", "GR") %in% colnames(df))) {
    stop("NGen/GR columns missing in processed data.")
  }

  pres_mat <- df[, strains, drop = FALSE]
  n_present <- rowSums(!is.na(pres_mat))

  mono_idx <- which(n_present == 1)
  if (length(mono_idx) == 0) {
    stop("No monocultures detected; diversity analysis requires at least 1 monoculture.")
  }
  mono_df <- df[mono_idx, , drop = FALSE]

  ngen_mono <- mono_df$NGen[is.finite(mono_df$NGen) & mono_df$NGen > 0]
  gr_mono   <- mono_df$GR[is.finite(mono_df$GR) & mono_df$GR > 0]

  best_ngen <- if (length(ngen_mono) > 0) max(ngen_mono, na.rm = TRUE) else NA_real_
  best_gr   <- if (length(gr_mono)   > 0) max(gr_mono,   na.rm = TRUE) else NA_real_

  if (!is.finite(best_ngen) || !is.finite(best_gr) || best_ngen <= 0 || best_gr <= 0) {
    msg <- paste0(
      "Diversity analysis skipped: relative fitness cannot be computed because ",
      "monocultures do not have finite NGen/GR (>0). ",
      "This usually happens when some curves remain flat (OD~0) after background correction ",
      "and GrowthCurver returns NA/0 for t_mid. ",
      "Suggestions: (1) try threshold-based correction, (2) check the blank ID/value, ",
      "(3) use the Grofit method."
    )
    bsocial_log("WARN", msg)

    empty <- data.frame()
    .Object@resultados_analisis$diversity_gen_table <- empty
    .Object@resultados_analisis$diversity_gr_table  <- empty
    .Object@resultados_analisis$diversity_message <- msg

    label_msg <- paste(strwrap(msg, width = 70), collapse = "\n")
    .Object@graficos$diversity_gen_plot <- ggplot2::ggplot() +
      ggplot2::annotate("text", x = 0.5, y = 0.5, label = label_msg, hjust = 0.5, vjust = 0.5, size = 4) +
      ggplot2::theme_void()
    .Object@graficos$diversity_gr_plot <- .Object@graficos$diversity_gen_plot

    return(.Object)
  }

  build_diversity_matrix <- function(metric_col, best_val) {
    sizes <- sort(unique(n_present))
    nr <- nrow(df)
    out <- matrix(NA_real_, nrow = nr, ncol = length(sizes))
    for (j in seq_along(sizes)) {
      s <- sizes[j]
      idx <- which(n_present == s & is.finite(df[[metric_col]]))
      out[idx, j] <- df[[metric_col]][idx] / best_val
    }
    colnames(out) <- as.character(sizes)
    as.data.frame(out)
  }

  plot_diversity_boxplot <- function(mat, ylab) {
    mx <- suppressMessages(reshape2::melt(mat, na.rm = TRUE))
    ggplot2::ggplot(mx, ggplot2::aes(x = variable, y = value, fill = variable)) +
      ggplot2::geom_boxplot() +
      ggplot2::geom_hline(yintercept = 1, linetype = 5, color = "gray") +
      ggplot2::labs(x = "Species richness in consortium", y = ylab, fill = "Diversity") +
      ggplot2::theme_minimal() +
      ggplot2::theme(legend.position = "none")
  }

  div_gen <- build_diversity_matrix("NGen", best_ngen)
  div_gr  <- build_diversity_matrix("GR",   best_gr)

  .Object@resultados_analisis$diversity_gen_table <- div_gen
  .Object@resultados_analisis$diversity_gr_table  <- div_gr

  .Object@graficos$diversity_gen_plot <- plot_diversity_boxplot(div_gen, "Relative Fitness (Generations)")
  .Object@graficos$diversity_gr_plot  <- plot_diversity_boxplot(div_gr,  "Relative Fitness (Growth Rate)")

  .Object
})
