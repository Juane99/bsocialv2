#' Analyze Biofilm Assembly Sequences
#'
#' Builds a directed graph of possible consortium assembly paths based on
#' strain subset relationships. Uses igraph to find shortest paths between
#' simpler and more complex consortia.
#'
#' @param .Object A \linkS4class{bsocial} object after \code{analyze_social_behavior()} has been called.
#' @return The modified \linkS4class{bsocial} object with biofilm paths and plot functions.
#'
#' @export
setMethod("analyze_biofilm_sequence", "bsocial", function(.Object) {
  df <- .Object@datos_procesados
  nstrains <- length(.Object@cepas_seleccionadas)

  generate_biofilm_data <- function(data, pos_name) {
    nconsortia <- nrow(data)
    if (nconsortia == 0) {
      return(list(
        graph = igraph::make_empty_graph(),
        paths = list(),
        data  = data,
        consortia_size = integer(0)
      ))
    }

    nas <- !is.na(data %>% dplyr::select(dplyr::all_of(.Object@cepas_seleccionadas)))
    consortia_size <- rowSums(nas)

    test.matrix <- matrix(0, ncol = nconsortia, nrow = nconsortia)
    for (i in seq_len(nconsortia)) {
      for (j in seq_len(nconsortia)) {
        uno <- which(nas[i, ])
        dos <- which(nas[j, ])
        mm  <- min(length(uno), length(dos))

        if (is.na(data[[pos_name]][i]) || is.na(data[[pos_name]][j])) {
          test.matrix[i, j] <- 0
        } else {
          test.matrix[i, j] <-
            ((data[[pos_name]][i] <= data[[pos_name]][j]) &&
             (length(intersect(uno, dos)) == mm) &&
             (length(dos) == mm + 1))
        }
      }
    }

    myg <- igraph::graph.adjacency(test.matrix, mode = "directed")

    end_node <- which(consortia_size == nstrains)
    monoculture_nodes <- which(consortia_size == 1)

    if (length(end_node) == 0 || length(monoculture_nodes) == 0) {
      return(list(
        graph = myg,
        paths = list(),
        data  = data,
        consortia_size = consortia_size
      ))
    }

    all_paths <- list()
    for (i in monoculture_nodes) {
      paths <- igraph::all_shortest_paths(myg, from = i, to = end_node, mode = "out")
      path_names <- lapply(paths$res, function(p) data$Consortia[p])
      all_paths[[data$Consortia[i]]] <- path_names
    }

    list(
      graph = myg,
      paths = all_paths,
      data  = data,
      consortia_size = consortia_size
    )
  }

  plot_biofilm <- function(biofilm_data, title) {
    g <- biofilm_data$graph
    if (igraph::gsize(g) > 0) {
      layout <- igraph::layout_with_sugiyama(g)$layout
      igraph::plot.igraph(
        g,
        layout = layout,
        vertex.size = 7,
        vertex.label = biofilm_data$data$Consortia,
        vertex.label.cex = 0.7,
        edge.arrow.size = 0.4,
        main = title
      )
    } else {
      plot(1, type = "n", axes = FALSE, xlab = "", ylab = "")
      title(main = title, sub = "No assembly paths found.")
    }
  }

  biofilm_gen <- generate_biofilm_data(df, "NGen")
  biofilm_gr  <- generate_biofilm_data(df, "GR")

  .Object@resultados_analisis$biofilm_gen_paths <- biofilm_gen$paths
  .Object@resultados_analisis$biofilm_gr_paths  <- biofilm_gr$paths

  .Object@graficos$biofilm_gen_plot_func <- function() {
    plot_biofilm(biofilm_gen, "Biofilm Sequence (Generations)")
  }
  .Object@graficos$biofilm_gr_plot_func <- function() {
    plot_biofilm(biofilm_gr, "Biofilm Sequence (Growth Rate)")
  }

  .Object
})
