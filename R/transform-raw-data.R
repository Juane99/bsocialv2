#' Preprocess Raw Plate Reader Data
#'
#' Normalizes raw plate reader data by applying background correction and
#' aggregating replicates. Supports blank-based or OD threshold correction.
#'
#' @param .Object A \linkS4class{bsocial} object with \code{datos_crudos$plates} populated.
#' @param groups Numeric vector defining replicate group assignments for each plate.
#' @param bg_type Character. Background correction method: \code{"blank"} or \code{"threshold"}.
#' @param bg_param Numeric or character. For \code{"blank"}: the blank sample ID.
#'   For \code{"threshold"}: the OD threshold value.
#' @return The modified \linkS4class{bsocial} object with \code{resultados_analisis} populated.
#'
#' @export
setMethod("transform_raw_data", "bsocial", function(.Object, groups, bg_type, bg_param) {
  bsocial_log("INFO", "transform_raw_data(): bg_type=", bg_type,
              " | bg_param=", bg_param,
              " | plates=", length(.Object@datos_crudos$plates))

  plates <- .Object@datos_crudos$plates
  cons   <- .Object@datos_crudos$consortia

  if (is.null(plates) || length(plates) == 0) {
    stop("No raw plate data found.")
  }
  if (is.null(groups) || length(groups) == 0) {
    groups <- seq_along(plates)
  }
  if (length(groups) != length(plates)) {
    stop("The groups vector does not match the number of plates.")
  }
  if (!bg_type %in% c("blank", "threshold")) {
    stop("Invalid bg_type. Use 'blank' or 'threshold'.")
  }

  # IDs válidos según consortia (columna Consortia preferente)
  valid_ids <- character(0)
  if (!is.null(cons) && is.data.frame(cons) && nrow(cons) > 0) {
    if ("Consortia" %in% colnames(cons)) {
      valid_ids <- trimws(as.character(cons$Consortia))
    } else {
      # fallback: primera columna
      valid_ids <- trimws(as.character(cons[[1]]))
    }
  }

  # ------------------------------------------------------------
  # Procesado individual de cada placa
  # ------------------------------------------------------------
  preprocessed_list <- lapply(seq_along(plates), function(ii) {
    plate_df <- as.data.frame(plates[[ii]], stringsAsFactors = FALSE, check.names = FALSE)

    # Limpieza de nombres: quitar "X" que R pueda poner delante de cabeceras numéricas
    colnames(plate_df) <- gsub("^X", "", colnames(plate_df))

    # Columnas meta
    meta_cols <- c("WellID", "SampleID")
    if (!all(meta_cols %in% colnames(plate_df))) {
      stop("Missing metadata columns in plate ", ii, ". Required: WellID and SampleID.")
    }

    plate_df$WellID   <- trimws(as.character(plate_df$WellID))
    plate_df$SampleID <- trimws(as.character(plate_df$SampleID))

    potential_times <- setdiff(colnames(plate_df), meta_cols)
    is_num <- !is.na(suppressWarnings(as.numeric(potential_times)))
    time_cols <- potential_times[is_num]

    if (length(time_cols) == 0) {
      stop(
        "No time columns detected in plate ", ii, ". Headers: ",
        paste(head(colnames(plate_df)), collapse = ", ")
      )
    }

    # Matriz OD (robusta)
    mat_vals <- plate_df[, time_cols, drop = FALSE]

    # Verificar que hay filas antes de procesar
    if (nrow(mat_vals) == 0) {
      stop("Plate ", ii, " has no valid data rows.")
    }

    # Convertir a numérico preservando dimensiones
    mat_vals <- as.matrix(mat_vals)
    mat_vals <- suppressWarnings(apply(mat_vals, 2, function(x) as.numeric(as.character(x))))

    # Recuperar dimensiones si apply() devolvió un vector (caso de 1 fila)
    if (is.null(dim(mat_vals))) {
      mat_vals <- matrix(mat_vals, nrow = 1, ncol = length(time_cols))
    }
    colnames(mat_vals) <- time_cols

    # --- Corrección de fondo ---
    if (bg_type == "blank") {
      blank_id <- as.character(bg_param)
      pos_blank <- which(plate_df$SampleID == blank_id)

      if (length(pos_blank) > 0) {
        bg <- stats::median(mat_vals[pos_blank, 1], na.rm = TRUE)
        if (!is.finite(bg)) bg <- 0

        mat_vals <- mat_vals - bg
        mat_vals[mat_vals < 0] <- 0

        plate_df[, time_cols] <- mat_vals
        # Eliminamos los blanks
        plate_df <- plate_df[plate_df$SampleID != blank_id, , drop = FALSE]
      } else {
        bsocial_log("WARN", "transform_raw_data(): no se encontró blank_id='", blank_id, "' en la placa ", ii)
      }

    } else if (bg_type == "threshold") {
      thr <- suppressWarnings(as.numeric(bg_param))
      if (is.na(thr)) thr <- 0.01

      t0 <- mat_vals[, 1]
      pos <- which(t0 <= thr)
      if (length(pos) > 0) {
        bg <- stats::median(t0[pos], na.rm = TRUE)
        if (!is.finite(bg)) bg <- 0

        mat_vals <- mat_vals - bg
        mat_vals[mat_vals < 0] <- 0
        plate_df[, time_cols] <- mat_vals
      } else {
        bsocial_log("WARN", "transform_raw_data(): no hay wells con t0<=thr (", thr, ") en la placa ", ii)
      }
    }

    # ------------------------------------------------------------
    # Filtrar a SOLO IDs presentes en Consortia (si hay consortia)
    # ------------------------------------------------------------
    if (length(valid_ids) > 0) {
      plate_df <- plate_df[plate_df$SampleID %in% valid_ids, , drop = FALSE]
      if (nrow(plate_df) == 0) {
        stop("IDs do not match between Consortia and plates (SampleID).")
      }
    }

    # Duplicados dentro de una misma placa: agregamos por media
    if (anyDuplicated(plate_df$SampleID) > 0) {
      bsocial_log("WARN", "transform_raw_data(): SampleID duplicados en placa ", ii, " -> agregando por media.")
      plate_df <- dplyr::group_by(plate_df, SampleID) %>%
        dplyr::summarise(
          WellID = dplyr::first(WellID),
          dplyr::across(dplyr::all_of(time_cols), ~ mean(suppressWarnings(as.numeric(.x)), na.rm = TRUE)),
          .groups = "drop"
        )
      plate_df <- plate_df[, c("WellID", "SampleID", time_cols), drop = FALSE]
    }

    plate_df
  })

  # ------------------------------------------------------------
  # Validación de columnas de tiempo (todas iguales)
  # ------------------------------------------------------------
  time_cols_list <- lapply(preprocessed_list, function(df) {
    meta_cols <- c("WellID", "SampleID")
    cn <- colnames(df)
    potential <- setdiff(cn, meta_cols)
    is_num <- !is.na(suppressWarnings(as.numeric(potential)))
    potential[is_num]
  })

  ref_cols <- time_cols_list[[1]]
  for (k in seq_along(time_cols_list)) {
    if (!setequal(ref_cols, time_cols_list[[k]])) {
      stop(
        paste0(
          "Plates do not have the same time columns.\n",
          "Some use seconds (0, 3600, 7200, ...) while others use indices (0, 1, 2, ...).\n",
          "Unify the time headers in your CSVs or analyze these groups separately."
        )
      )
    }
  }

  ref_cols <- ref_cols[order(as.numeric(ref_cols))]
  .Object@resultados_analisis$cycles <- as.numeric(ref_cols)

  # ------------------------------------------------------------
  # Unir réplicas por grupo (alineando por SampleID)
  # ------------------------------------------------------------
  unique_groups <- unique(groups)

  nf <- vector("list", length(unique_groups))
  sd_by_group <- rep(NA_real_, length(unique_groups))

  # Lista para guardar curvas individuales de cada réplica (para cálculo de CV)
  individual_replicate_curves <- list()

  for (gi in seq_along(unique_groups)) {
    g <- unique_groups[gi]
    sel <- which(groups == g)
    X <- preprocessed_list[sel]

    ids_list <- lapply(X, function(df) trimws(as.character(df$SampleID)))
    common_ids <- Reduce(intersect, ids_list)

    all_ids <- Reduce(union, ids_list)
    if (length(common_ids) < length(all_ids)) {
      bsocial_log("WARN", "transform_raw_data(): grupo ", g,
                  " -> se descartan ", length(all_ids) - length(common_ids),
                  " IDs que no están presentes en todas las réplicas.")
    }

    if (length(common_ids) == 0) {
      stop("Group ", g, " has no common SampleIDs across its replicates.")
    }

    # Orden estable según consortia (si existe)
    if (length(valid_ids) > 0) {
      common_ids <- valid_ids[valid_ids %in% common_ids]
    } else {
      common_ids <- sort(common_ids)
    }

    mats <- lapply(X, function(df) {
      idx <- match(common_ids, df$SampleID)
      if (any(is.na(idx))) {
        stop("Group ", g, " is missing SampleIDs in some replicates. (Incomplete common IDs)")
      }
      m <- as.matrix(df[idx, ref_cols, drop = FALSE])
      storage.mode(m) <- "numeric"
      m
    })

    # QC: SD entre réplicas (si hay más de 1)
    if (length(mats) > 1) {
      arr <- array(unlist(mats),
                   dim = c(nrow(mats[[1]]), ncol(mats[[1]]), length(mats)))
      sdm <- apply(arr, 1:2, stats::sd, na.rm = TRUE)
      sd_by_group[gi] <- suppressWarnings(max(sdm, na.rm = TRUE))
    }

    # Media
    if (length(mats) == 1) {
      avg <- mats[[1]]
    } else {
      avg <- apply(arr, 1:2, mean, na.rm = TRUE)
    }

    res <- as.data.frame(avg, check.names = FALSE)
    rownames(res) <- common_ids
    colnames(res) <- ref_cols
    nf[[gi]] <- res

    # Guardar curvas individuales de cada réplica para cálculo de CV
    for (rep_idx in seq_along(mats)) {
      rep_df <- as.data.frame(mats[[rep_idx]], check.names = FALSE)
      rownames(rep_df) <- common_ids
      colnames(rep_df) <- ref_cols
      rep_df$SampleID <- common_ids
      rep_df$group_id <- g
      rep_df$replicate_id <- rep_idx
      individual_replicate_curves[[length(individual_replicate_curves) + 1]] <- rep_df
    }
  }

  # Unimos todos los grupos
  final_curves <- do.call(rbind, nf)
  colnames(final_curves) <- gsub("^X", "", colnames(final_curves))

  # Mapa de IDs: curve_id (único) -> Consortia original + grupo
  consortia_ids <- unlist(lapply(nf, rownames), use.names = FALSE)
  group_ids_rep <- rep(unique_groups, times = vapply(nf, nrow, integer(1)))
  curve_id <- make.unique(paste0(consortia_ids, "__g", group_ids_rep))

  rownames(final_curves) <- curve_id
  .Object@resultados_analisis$final_curves <- final_curves
  .Object@resultados_analisis$curve_map <- data.frame(
    curve_id = curve_id,
    Consortia = consortia_ids,
    group_id = group_ids_rep,
    stringsAsFactors = FALSE
  )

  .Object@resultados_analisis$replicate_sd_by_group <- stats::setNames(sd_by_group, unique_groups)
  .Object@resultados_analisis$replicate_sd_max <- if (all(is.na(sd_by_group))) NA_real_ else max(sd_by_group, na.rm = TRUE)

  # Guardar curvas individuales de réplicas (para cálculo de CV en analyze_stability)
  .Object@resultados_analisis$individual_replicate_curves <- dplyr::bind_rows(individual_replicate_curves)

  # Datos para el plot de curvas promediadas (por grupo)
  .Object@resultados_analisis$mean_growth_data <- dplyr::bind_rows(
    lapply(seq_along(nf), function(i) {
      d <- nf[[i]]
      d$SampleID <- rownames(d)
      d$group_id <- unique_groups[i]
      d
    })
  )

  .Object
})
