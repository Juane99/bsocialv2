#' @keywords internal
"_PACKAGE"

#' @import methods
#' @importFrom dplyr %>%
#' @importFrom rlang .data
#' @importFrom stats lm cor.test median sd na.omit setNames pairwise.t.test as.formula
#' @importFrom grDevices colorRampPalette
#' @importFrom utils head
NULL

# Suppress R CMD check notes for data-variable bindings used in dplyr/ggplot2
utils::globalVariables(c(
  "SampleID", "group_id", "variable", "value", "type", "pos", "label",
  "WellID", "NGen", "GR", "LogPhase", "n_cepas", "myaxis", "x_numeric",
  "mean_NGen", "sd_NGen", "mean_GR", "sd_GR", "n_replicates",
  "n_consortia", "num", "od", "time"
))
