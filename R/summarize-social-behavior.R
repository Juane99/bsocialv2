#' Classify Strains as Cooperators, Cheaters, or Neutrals
#'
#' Uses pairwise t-tests and median comparisons to classify each strain
#' based on its effect on consortium fitness.
#'
#' @param .Object A \linkS4class{bsocial} object after \code{analyze_social_behavior()} has been called.
#' @return The modified \linkS4class{bsocial} object with \code{resultados_analisis$summary_gen} and \code{$summary_gr}.
#'
#' @export
setMethod("summarize_social_behavior", "bsocial", function(.Object) {
  bsocial_log("INFO", "summarize_social_behavior(): iniciando")

  sb <- .Object@resultados_analisis$social_behavior

  if (is.null(sb) || !isTRUE(sb$success)) {
    cepas <- .Object@cepas_seleccionadas
    nstrains <- length(cepas)
    empty_lists <- list(
      positives = character(0),
      negatives = character(0),
      neutrals  = character(0)
    )
    empty_stats <- data.frame(
      strain         = cepas,
      median_all     = rep(NA_real_, nstrains),
      median_not     = rep(NA_real_, nstrains),
      median_present = rep(NA_real_, nstrains),
      p_all_vs_not   = rep(NA_real_, nstrains),
      p_all_vs_pres  = rep(NA_real_, nstrains),
      p_not_vs_pres  = rep(NA_real_, nstrains),
      classification = rep("Neutral", nstrains),
      stringsAsFactors = FALSE
    )
    .Object@resultados_analisis$summary_gen <- empty_lists
    .Object@resultados_analisis$summary_gr  <- empty_lists
    .Object@resultados_analisis$stats_gen   <- empty_stats
    .Object@resultados_analisis$stats_gr    <- empty_stats
    return(.Object)
  }

  cepas <- .Object@cepas_seleccionadas
  nstrains <- length(cepas)

  summarize_one_metric <- function(data_for_boxplot) {
    empty_stats <- data.frame(
      strain           = cepas,
      median_all       = rep(NA_real_, nstrains),
      median_not       = rep(NA_real_, nstrains),
      median_present   = rep(NA_real_, nstrains),
      p_all_vs_not     = rep(NA_real_, nstrains),
      p_all_vs_pres    = rep(NA_real_, nstrains),
      p_not_vs_pres    = rep(NA_real_, nstrains),
      classification   = rep("Neutral", nstrains),
      stringsAsFactors = FALSE
    )
    empty_out <- list(
      positives = character(0),
      negatives = character(0),
      neutrals  = character(0),
      stats     = empty_stats
    )

    if (is.null(data_for_boxplot) || nrow(data_for_boxplot) == 0) {
      return(empty_out)
    }

    list_anova <- list()
    for (i in seq_len(nstrains)) {
      all_col  <- data_for_boxplot[, (i - 1) * 3 + 1]
      not_col  <- data_for_boxplot[, (i - 1) * 3 + 2]
      pres_col <- data_for_boxplot[, (i - 1) * 3 + 3]

      dataOneWayComparisons <- rbind(
        cbind(Treatment = paste0(cepas[i], "_ALL"),        Fitness = all_col),
        cbind(Treatment = paste0(cepas[i], "_NotPresent"), Fitness = not_col),
        cbind(Treatment = paste0(cepas[i], "_Present"),    Fitness = pres_col)
      )

      dfw <- as.data.frame(dataOneWayComparisons, stringsAsFactors = FALSE)
      dfw$Fitness <- suppressWarnings(as.numeric(dfw$Fitness))
      dfw <- stats::na.omit(dfw)

      list_anova[[cepas[i]]] <- dfw
    }

    p_all_vs_not  <- rep(NA_real_, nstrains)
    p_all_vs_pres <- rep(NA_real_, nstrains)
    p_not_vs_pres <- rep(NA_real_, nstrains)
    signif <- logical(nstrains)

    for (j in seq_len(nstrains)) {
      dataOneWayComparisons <- list_anova[[j]]
      if (nrow(dataOneWayComparisons) == 0 ||
          length(unique(dataOneWayComparisons$Treatment)) < 2) {
        next
      }
      tt <- try(
        stats::pairwise.t.test(
          dataOneWayComparisons$Fitness,
          dataOneWayComparisons$Treatment,
          p.adjust.method = "none"
        ),
        silent = TRUE
      )
      if (inherits(tt, "try-error") || is.null(tt$p.value)) next

      pmat <- tt$p.value
      if (nrow(pmat) >= 1 && ncol(pmat) >= 1) p_all_vs_not[j]  <- pmat[1, 1]
      if (nrow(pmat) >= 2 && ncol(pmat) >= 1) p_all_vs_pres[j] <- pmat[2, 1]
      if (nrow(pmat) >= 2 && ncol(pmat) >= 2) p_not_vs_pres[j] <- pmat[2, 2]

      min_p <- suppressWarnings(min(pmat, na.rm = TRUE))
      if (is.finite(min_p) && min_p <= 0.05 &&
          !is.na(p_not_vs_pres[j]) && p_not_vs_pres[j] <= 0.05) {
        signif[j] <- TRUE
      }
    }

    medianas <- apply(data_for_boxplot, 2, stats::median, na.rm = TRUE)
    m_all  <- medianas[seq(1, 3 * nstrains, 3)]
    m_not  <- medianas[seq(2, 3 * nstrains, 3)]
    m_pres <- medianas[seq(3, 3 * nstrains, 3)]

    cooperators       <- !is.na(m_not) & !is.na(m_pres) & (m_not < m_pres)
    cheaters          <- !is.na(m_not) & !is.na(m_pres) & (m_not > m_pres)
    absolute_cheaters <- !is.na(m_all) & !is.na(m_not) & !is.na(m_pres) &
                         (m_not > 1 & m_pres > 1 & m_all > 1)

    pos_mask <- cooperators & signif
    neg_mask <- absolute_cheaters | (cheaters & signif)
    neu_mask <- !pos_mask & !neg_mask

    classification <- rep("Neutral", nstrains)
    classification[pos_mask] <- "Cooperator"
    classification[neg_mask] <- "Cheater"

    list(
      positives = cepas[pos_mask],
      negatives = cepas[neg_mask],
      neutrals  = cepas[neu_mask],
      stats = data.frame(
        strain           = cepas,
        median_all       = unname(m_all),
        median_not       = unname(m_not),
        median_present   = unname(m_pres),
        p_all_vs_not     = p_all_vs_not,
        p_all_vs_pres    = p_all_vs_pres,
        p_not_vs_pres    = p_not_vs_pres,
        classification   = classification,
        stringsAsFactors = FALSE
      )
    )
  }

  summary_gen <- summarize_one_metric(sb$data_gen)
  summary_gr  <- summarize_one_metric(sb$data_gr)

  .Object@resultados_analisis$summary_gen <- summary_gen[c("positives", "negatives", "neutrals")]
  .Object@resultados_analisis$summary_gr  <- summary_gr[c("positives", "negatives", "neutrals")]
  .Object@resultados_analisis$stats_gen   <- summary_gen$stats
  .Object@resultados_analisis$stats_gr    <- summary_gr$stats

  # Rebuild social plots now that classification is available, using the
  # helper lifted in Task A4.
  sb$social_generations_plot <- generate_social_plot(
    sb$data_gen, cepas, "Fitness over number of generations", "Fitness (NGen)",
    stats_tbl = summary_gen$stats
  )
  sb$social_gr_plot <- generate_social_plot(
    sb$data_gr, cepas, "Fitness over growth rate", "Fitness (GR)",
    stats_tbl = summary_gr$stats
  )
  .Object@resultados_analisis$social_behavior <- sb

  .Object
})
