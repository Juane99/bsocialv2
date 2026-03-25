#' Calculate Growth Parameters from Preprocessed Curves
#'
#' Fits growth curves and extracts LogPhase, number of generations (NGen),
#' and growth rate (GR) for each consortium.
#'
#' @param .Object A \linkS4class{bsocial} object after \code{transform_raw_data()} has been called.
#' @param method Character. Fitting algorithm: \code{"growthcurver"} (default) or \code{"grofit"}.
#' @return The modified \linkS4class{bsocial} object with \code{datos_procesados} populated.
#'
#' @export
setMethod("calculate_growth_params", "bsocial", function(.Object, method = "growthcurver") {
  bsocial_log("INFO", "calculate_growth_params(): method=", method)

  final_curves <- .Object@resultados_analisis$final_curves
  cycles <- .Object@resultados_analisis$cycles
  curve_map <- .Object@resultados_analisis$curve_map

  if (is.null(final_curves) || nrow(final_curves) == 0) {
    stop("No preprocessed curves found. Complete Step 2 first.")
  }
  if (is.null(cycles) || length(cycles) == 0) {
    stop("No time cycles detected.")
  }
  if (!method %in% c("growthcurver", "grofit")) {
    stop("Invalid method. Use 'growthcurver' or 'grofit'.")
  }
  if (method == "grofit" && !requireNamespace("grofit", quietly = TRUE)) {
    stop("The 'grofit' package is required for method='grofit' but is not installed. ",
         "grofit has been archived from CRAN. Install it with:\n",
         "  install.packages(\"https://cran.r-project.org/src/contrib/Archive/grofit/grofit_1.1.1-1.tar.gz\", repos = NULL, type = \"source\")\n",
         "Or use method='growthcurver' instead.")
  }
  if (is.null(curve_map) || !"curve_id" %in% colnames(curve_map)) {
    stop("curve_map not found. Please re-run Step 2.")
  }

  curve_id <- rownames(final_curves)
  n <- length(curve_id)

  ngen_vec <- rep(NA_real_, n)
  gr_vec   <- rep(NA_real_, n)

  if (method == "growthcurver") {
    data_for_gc <- as.data.frame(t(final_curves), check.names = FALSE)
    data_for_gc <- cbind(time = cycles, data_for_gc)

    gc <- as.data.frame(apply(data_for_gc, 2, as.numeric))
    sc <- growthcurver::SummarizeGrowthByPlate(gc, bg_correct = "none")

    # Warnings de ajuste
    duda <- which(sc$note != "")
    if (length(duda) > 0) {
      for (ii in duda) {
        warning(call. = FALSE, paste(sc[ii, ]$note, "en", sc[ii, ]$sample))
      }
    }

    # Alineamos por curve_id (sc$sample)
    pos <- match(curve_id, sc$sample)
    if (any(is.na(pos))) {
      stop("GrowthCurver did not return results for all curves.")
    }
    sc <- sc[pos, , drop = FALSE]

    # Conversion consistent with v1
    ngen_vec <- sc$t_mid / 360
    ngen_vec[!is.finite(ngen_vec) | ngen_vec < 0] <- NA_real_

    gr_vec <- rep(NA_real_, length(ngen_vec))
    ok <- is.finite(ngen_vec) & ngen_vec > 0
    gr_vec[ok] <- 1 / ngen_vec[ok]
    gr_vec[!is.finite(gr_vec)] <- NA_real_
  } else if (method == "grofit") {
    mytime <- as.data.frame(t(matrix(rep(cycles, n), nrow = length(cycles), ncol = n)))
    input_data <- data.frame(exp_id = "a", add_info = "b", concentration = 0, final_curves,
                             check.names = FALSE, stringsAsFactors = FALSE)

    config <- grofit::grofit.control(log.y.gc = TRUE, interactive = FALSE, suppress.messages = TRUE)
    out <- grofit::gcFit(mytime, input_data, control = config)

    faulty <- which(is.na(apply(out$gcTable[, 9:28, drop = FALSE], 1, sum)))
    unfaulty <- seq_len(n)
    if (length(faulty) > 0) unfaulty <- unfaulty[-faulty]

    ld <- lapply(unfaulty, function(i) {
      used <- as.character(out$gcTable[i, ]$used.model)

      if (used == "gompertz") {
        x <- grofit::gompertz(unlist(mytime[i, ]), out$gcTable[i, ]$A.model, out$gcTable[i, ]$mu.model, out$gcTable[i, ]$lambda.model)
      } else if (used == "logistic") {
        x <- grofit::logistic(unlist(mytime[i, ]), out$gcTable[i, ]$A.model, out$gcTable[i, ]$mu.model, out$gcTable[i, ]$lambda.model)
      } else if (used == "richards") {
        x <- grofit::richards(unlist(mytime[i, ]), out$gcTable[i, ]$A.model, out$gcTable[i, ]$mu.model, out$gcTable[i, ]$lambda.model, out$gcFittedModels[[i]]$nls$m$getAllPars()[4])
      } else if (used == "gompertz.exp") {
        x <- grofit::gompertz.exp(unlist(mytime[i, ]), out$gcTable[i, ]$A.model, out$gcTable[i, ]$mu.model, out$gcTable[i, ]$lambda.model, out$gcFittedModels[[i]]$nls$m$getAllPars()[4])
      } else {
        warning("Modelo grofit desconocido: ", used)
        return(c(NA_real_, NA_real_))
      }

      start <- which(x >= trunc(out$gcTable[i, ]$A.model * 1000) / 1000)[1]
      if (is.na(start)) return(c(NA_real_, NA_real_))

      d <- abs(x - out$gcFittedModels[[i]]$raw.data)

      pos <- integer(0)
      epsilon <- 0.001
      max_epsilon <- 1.0
      prestart <- ifelse(start - 5 > 0, start - 5, 1)
      while (length(pos) == 0 && epsilon <= max_epsilon) {
        pos <- which(d[prestart:start] < epsilon) + prestart - 1
        epsilon <- epsilon + 0.004
      }

      if (length(pos) == 0) {
        return(c(NA_real_, NA_real_))
      }
      elmin <- min(d[pos])
      pos <- which(d[pos] == elmin) + pos[1] - 1

      growth_idx <- pos[length(pos)]
      growth_val <- out$gcFittedModels[[i]]$raw.data[growth_idx]

      new_start <- growth_idx
      dtop <- max(out$gcFittedModels[[i]]$raw.data[1:new_start])
      dmax <- which(out$gcFittedModels[[i]]$raw.data[1:new_start] == dtop)
      gen_val <- dtop

      if (is.na(gen_val) || is.na(growth_val) || gen_val <= 0 || growth_val <= 0) {
        return(c(NA_real_, NA_real_))
      }

      ngen <- (log(gen_val) - log(growth_val)) / log(2)

      if (!is.finite(ngen) || ngen == 0) {
        return(c(NA_real_, NA_real_))
      }

      gr <- (dmax[length(dmax)] - growth_idx) / ngen

      c(ngen, gr)
    })

    ngen_vec[unfaulty] <- unlist(ld)[seq(1, length(ld) * 2, 2)]
    gr_vec[unfaulty]   <- unlist(ld)[seq(2, length(ld) * 2, 2)]
  }

  log_phase <- ngen_vec / gr_vec
  log_phase[!is.finite(log_phase)] <- NA_real_

  growth_params <- data.frame(
    curve_id  = curve_id,
    LogPhase  = log_phase,
    NGen      = ngen_vec,
    GR        = gr_vec,
    stringsAsFactors = FALSE
  )

  .Object@resultados_analisis$growth_params <- growth_params

  # Incorporamos Consortia original y group_id
  growth_params <- dplyr::left_join(curve_map, growth_params, by = "curve_id")

  # Merge with consortia to add presence/absence columns
  cons <- .Object@datos_crudos$consortia
  if (!is.null(cons) && is.data.frame(cons) && nrow(cons) > 0) {
    if (!"Consortia" %in% colnames(cons)) colnames(cons)[1] <- "Consortia"
    cons$Consortia <- trimws(as.character(cons$Consortia))
    growth_params$Consortia <- trimws(as.character(growth_params$Consortia))

    final_df <- dplyr::left_join(growth_params, cons, by = "Consortia")

    cols_keep <- c("Consortia", "group_id", .Object@cepas_seleccionadas, "LogPhase", "NGen", "GR")
    cols_keep <- cols_keep[cols_keep %in% colnames(final_df)]
    final_df <- final_df[, cols_keep, drop = FALSE]
  } else {
    final_df <- growth_params
  }

  .Object@datos_procesados <- final_df
  .Object
})
