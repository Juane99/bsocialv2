#' Analyze Consortium Stability
#'
#' Calculates the coefficient of variation (CV) for growth metrics across
#' replicates or diversity levels. Creates violin plots with Spearman
#' correlation, p-value, and R-squared displayed as subtitles.
#'
#' @param .Object A \linkS4class{bsocial} object with \code{datos_procesados} populated.
#' @return The modified \linkS4class{bsocial} object with stability analysis results.
#'
#' @export
setMethod("analyze_stability", "bsocial", function(.Object) {
  bsocial_log("INFO", "analyze_stability(): iniciando")

  df <- .Object@datos_procesados
  strains <- .Object@cepas_seleccionadas
  is_raw <- !is.null(.Object@datos_crudos$type) && .Object@datos_crudos$type == "raw"

  if (is.null(df) || nrow(df) == 0) {
    stop("No processed data available for stability analysis.")
  }

  if (!all(c("NGen", "GR") %in% colnames(df))) {
    stop("NGen/GR columns missing in processed data.")
  }

  pres_mat <- df[, strains, drop = FALSE]
  df$n_cepas <- rowSums(!is.na(pres_mat))

  create_violin_plot <- function(data, x_col, y_col, ylab, title) {
    plot_data <- data[is.finite(data[[y_col]]) & data[[y_col]] > 0, , drop = FALSE]

    if (nrow(plot_data) < 3) {
      return(
        ggplot2::ggplot() +
          ggplot2::annotate("text", x = 0.5, y = 0.5,
                            label = "Insufficient data for analysis",
                            size = 5, hjust = 0.5) +
          ggplot2::theme_void() +
          ggplot2::ggtitle(title)
      )
    }

    sample_size <- plot_data %>%
      dplyr::group_by(.data[[x_col]]) %>%
      dplyr::summarize(num = dplyr::n(), .groups = "drop")

    plot_data <- dplyr::left_join(plot_data, sample_size, by = x_col)
    plot_data$myaxis <- paste0(plot_data[[x_col]], "\nn=", plot_data$num)

    plot_data$myaxis <- factor(plot_data$myaxis,
                                levels = unique(plot_data$myaxis[order(plot_data[[x_col]])]))

    lm_fit <- tryCatch({
      stats::lm(as.formula(paste(y_col, "~", x_col)), data = plot_data)
    }, error = function(e) NULL)

    r_squared <- if (!is.null(lm_fit)) {
      summary(lm_fit)$r.squared
    } else {
      NA
    }

    cor_test <- tryCatch({
      stats::cor.test(plot_data[[x_col]], plot_data[[y_col]], method = "spearman")
    }, error = function(e) {
      bsocial_log("WARN", "analyze_stability(): correlacion fallo - ", e$message)
      NULL
    })

    rho <- if (!is.null(cor_test)) cor_test$estimate else NA
    p_val <- if (!is.null(cor_test)) cor_test$p.value else NA

    if (!is.na(rho) && !is.na(p_val) && is.finite(rho) && is.finite(p_val) && is.finite(r_squared)) {
      subtitle_text <- bquote(rho == .(round(rho, 2)) ~ "|" ~ italic(p) == .(format(p_val, digits = 2)) ~
                               "|" ~ R^2 == .(round(r_squared, 2)))
    } else {
      subtitle_text <- ""
    }

    n_levels <- length(unique(plot_data[[x_col]]))
    green_palette <- grDevices::colorRampPalette(c("#a1d99b", "#006d2c"))(n_levels)

    plot_data$x_numeric <- as.numeric(factor(plot_data$myaxis))

    p <- ggplot2::ggplot(plot_data, ggplot2::aes(x = myaxis, y = .data[[y_col]])) +
      ggplot2::geom_violin(ggplot2::aes(fill = factor(.data[[x_col]])), width = 1.2, alpha = 0.8) +
      ggplot2::geom_boxplot(width = 0.15, color = "black", alpha = 0.3, outlier.shape = NA) +
      ggplot2::geom_smooth(ggplot2::aes(x = x_numeric), method = "lm", se = FALSE,
                           color = "#feb24c", linewidth = 1.5) +
      ggplot2::scale_fill_manual(values = green_palette) +
      ggplot2::labs(
        x = "Number of species",
        y = ylab,
        title = title,
        subtitle = subtitle_text
      ) +
      ggplot2::theme_minimal() +
      ggplot2::theme(
        legend.position = "none",
        axis.title = ggplot2::element_text(size = 12),
        axis.text = ggplot2::element_text(size = 10),
        plot.title = ggplot2::element_text(size = 14, face = "bold"),
        plot.subtitle = ggplot2::element_text(size = 11)
      )

    p
  }

  if (is_raw && !is.null(.Object@resultados_analisis$individual_replicate_curves)) {
    bsocial_log("INFO", "analyze_stability(): calculando CV desde replicas individuales")

    replicate_curves <- .Object@resultados_analisis$individual_replicate_curves
    cycles <- .Object@resultados_analisis$cycles

    if (!is.data.frame(replicate_curves) || nrow(replicate_curves) == 0) {
      bsocial_log("WARN", "analyze_stability(): individual_replicate_curves vacio o invalido, usando metodo curated")
      is_raw <- FALSE
    }

    if (is.null(cycles) || length(cycles) == 0) {
      stop("No time cycles found for parameter calculation.")
    }

    time_cols <- as.character(cycles)
    time_cols <- time_cols[time_cols %in% colnames(replicate_curves)]

    if (length(time_cols) == 0) {
      stop("No time columns found in replicate curves.")
    }

    unique_samples <- unique(replicate_curves$SampleID)
    replicate_params <- list()

    for (i in seq_len(nrow(replicate_curves))) {
      row_data <- as.numeric(replicate_curves[i, time_cols])

      if (all(is.na(row_data)) || all(row_data == 0, na.rm = TRUE)) {
        replicate_params[[i]] <- data.frame(
          SampleID = replicate_curves$SampleID[i],
          group_id = replicate_curves$group_id[i],
          replicate_id = replicate_curves$replicate_id[i],
          NGen = NA_real_,
          GR = NA_real_,
          stringsAsFactors = FALSE
        )
        next
      }

      if (length(cycles) != length(row_data)) {
        bsocial_log("WARN", "analyze_stability(): dimensiones no coinciden para replica ", i)
        replicate_params[[i]] <- data.frame(
          SampleID = replicate_curves$SampleID[i],
          group_id = replicate_curves$group_id[i],
          replicate_id = replicate_curves$replicate_id[i],
          NGen = NA_real_,
          GR = NA_real_,
          stringsAsFactors = FALSE
        )
        next
      }

      gc_data <- data.frame(time = cycles, values = row_data)

      fit <- tryCatch({
        growthcurver::SummarizeGrowth(gc_data$time, gc_data$values, bg_correct = "none")
      }, error = function(e) NULL)

      if (!is.null(fit) && !is.null(fit$vals$t_mid) && is.finite(fit$vals$t_mid) && fit$vals$t_mid > 0) {
        ngen_val <- fit$vals$t_mid / 360
        gr_val <- if (ngen_val > 0) 1 / ngen_val else NA_real_
      } else {
        ngen_val <- NA_real_
        gr_val <- NA_real_
      }

      replicate_params[[i]] <- data.frame(
        SampleID = replicate_curves$SampleID[i],
        group_id = replicate_curves$group_id[i],
        replicate_id = replicate_curves$replicate_id[i],
        NGen = ngen_val,
        GR = gr_val,
        stringsAsFactors = FALSE
      )
    }

    replicate_params_df <- dplyr::bind_rows(replicate_params)

    cv_by_consortia <- replicate_params_df %>%
      dplyr::group_by(SampleID, group_id) %>%
      dplyr::summarize(
        n_replicates = dplyr::n(),
        mean_NGen = mean(NGen, na.rm = TRUE),
        sd_NGen = stats::sd(NGen, na.rm = TRUE),
        CV_NGen = ifelse(mean_NGen > 1e-6 & is.finite(mean_NGen), sd_NGen / mean_NGen, NA_real_),
        mean_GR = mean(GR, na.rm = TRUE),
        sd_GR = stats::sd(GR, na.rm = TRUE),
        CV_GR = ifelse(mean_GR > 1e-6 & is.finite(mean_GR), sd_GR / mean_GR, NA_real_),
        .groups = "drop"
      )

    cons <- .Object@datos_crudos$consortia
    if (!is.null(cons) && "Consortia" %in% colnames(cons)) {
      cons$n_cepas <- rowSums(!is.na(cons[, strains, drop = FALSE]))
      cv_by_consortia <- dplyr::left_join(
        cv_by_consortia,
        cons[, c("Consortia", "n_cepas")],
        by = c("SampleID" = "Consortia")
      )
    } else {
      cv_by_consortia <- dplyr::left_join(
        cv_by_consortia,
        df[, c("Consortia", "n_cepas")],
        by = c("SampleID" = "Consortia")
      )
    }

    if (!"n_cepas" %in% colnames(cv_by_consortia) || all(is.na(cv_by_consortia$n_cepas))) {
      bsocial_log("WARN", "analyze_stability(): no se pudo determinar n_cepas para algunos consorcios")
      if (!"n_cepas" %in% colnames(cv_by_consortia)) {
        cv_by_consortia$n_cepas <- NA_integer_
      }
    }

    .Object@resultados_analisis$stability_cv_data <- cv_by_consortia
    .Object@resultados_analisis$stability_replicate_params <- replicate_params_df

    .Object@graficos$stability_ngen_plot <- create_violin_plot(
      cv_by_consortia, "n_cepas", "CV_NGen",
      "Coefficient of Variation (CV)",
      "Stability - Number of Generations"
    )

    .Object@graficos$stability_gr_plot <- create_violin_plot(
      cv_by_consortia, "n_cepas", "CV_GR",
      "Coefficient of Variation (CV)",
      "Stability - Growth Rate"
    )

  } else {
    bsocial_log("INFO", "analyze_stability(): calculando CV agrupando por diversidad (datos curated)")

    cv_by_diversity <- df %>%
      dplyr::group_by(n_cepas) %>%
      dplyr::summarize(
        n_consortia = dplyr::n(),
        mean_NGen = mean(NGen, na.rm = TRUE),
        sd_NGen = stats::sd(NGen, na.rm = TRUE),
        CV_NGen = ifelse(mean_NGen > 1e-6 & is.finite(mean_NGen), sd_NGen / mean_NGen, NA_real_),
        mean_GR = mean(GR, na.rm = TRUE),
        sd_GR = stats::sd(GR, na.rm = TRUE),
        CV_GR = ifelse(mean_GR > 1e-6 & is.finite(mean_GR), sd_GR / mean_GR, NA_real_),
        .groups = "drop"
      )

    .Object@resultados_analisis$stability_cv_by_diversity <- cv_by_diversity

    .Object@graficos$stability_ngen_plot <- create_violin_plot(
      df, "n_cepas", "NGen",
      "Number of Generations",
      "Distribution by Diversity - NGen"
    )

    .Object@graficos$stability_gr_plot <- create_violin_plot(
      df, "n_cepas", "GR",
      "Growth Rate",
      "Distribution by Diversity - GR"
    )

    .Object@resultados_analisis$stability_cv_data <- cv_by_diversity
  }

  bsocial_log("INFO", "analyze_stability(): completado")
  .Object
})
