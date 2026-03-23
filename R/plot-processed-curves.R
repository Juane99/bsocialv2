#' Plot Preprocessed Growth Curves
#'
#' Creates a faceted line plot of mean growth curves after preprocessing,
#' grouped by experimental condition.
#'
#' @param .Object A \linkS4class{bsocial} object after \code{transform_raw_data()} has been called.
#' @return A ggplot2 object.
#'
#' @export
setMethod("plot_processed_curves", "bsocial", function(.Object) {
  if (is.null(.Object@resultados_analisis$mean_growth_data)) {
    stop("No averaged growth data available for plotting.")
  }

  plot_df <- .Object@resultados_analisis$mean_growth_data %>%
    tidyr::pivot_longer(
      cols = -c(SampleID, group_id),
      names_to = "time",
      values_to = "od"
    ) %>%
    dplyr::mutate(time = as.numeric(time))

  p <- ggplot2::ggplot(plot_df, ggplot2::aes(x = time, y = od, group = SampleID, color = factor(group_id))) +
    ggplot2::geom_line(alpha = 0.7) +
    viridis::scale_color_viridis(discrete = TRUE, name = "Exp. Group") +
    ggplot2::labs(
      title = "Pre-processed Growth Curves",
      subtitle = "Each line represents a consortium averaged across its replicates.",
      x = "Time (seconds)",
      y = "Optical Density (OD)"
    ) +
    ggplot2::theme_minimal()

  return(p)
})
