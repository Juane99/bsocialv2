# bsocialv2 + BSocialApp UI and Package Updates — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver six coordinated UI/package improvements — log10 growth-curve axis, IQR-based outlier toggle on the LogPhase-vs-NGen scatter, cooperator/cheater/neutral badges on social facets, a downloadable Statistics sub-tab in Social, removal of the Top-k Best Strains path, and an axis rename in Diversity — across the `bsocialv2` R package (bump to v0.2.0) and the `BSocialApp` Shiny companion.

**Architecture:** Two-phase release. Phase A modifies the `bsocialv2` package (testthat-driven where possible) and pushes v0.2.0 to GitHub main. Phase B updates the app's pinned SHA via `renv::update()`, then edits the three affected Shiny modules. Plot generation for the growth scatter moves from cached (inside `analyze_growth()`) to on-demand (new `plot_growth_scatter()` function) so the app checkbox can drive reactivity without rerunning the analysis.

**Tech Stack:** R 4.0+, S4 classes, ggplot2, testthat 3e, roxygen2, devtools, Shiny (bslib, DT), renv, rsconnect.

**Reference spec:** `docs/superpowers/specs/2026-04-20-bsocial-ui-package-updates-design.md`

**Source repos:**
- Package: `C:\Users\juane\Documents\GitHub\bsocialv2`
- App: `C:\Users\juane\Documents\GitHub\BSocialApp`

---

## Phase A — Package changes (`bsocialv2`)

### Task A1: Feature branch + baseline test run

**Files:**
- No changes. Verification only.

- [ ] **Step 1: Create feature branch from main**

Run:
```bash
cd 'C:\Users\juane\Documents\GitHub\bsocialv2'
git checkout -b feature/ui-package-updates-v0.2.0
```
Expected: `Switched to a new branch 'feature/ui-package-updates-v0.2.0'`

- [ ] **Step 2: Run the existing test suite to confirm green baseline**

Run:
```bash
Rscript -e "devtools::test()"
```
Expected: All tests pass (11 test files). If any test fails, **stop** and fix the baseline before continuing.

---

### Task A2: log10 y-axis in `plot_processed_curves`

**Files:**
- Modify: `R/plot-processed-curves.R:23-32`
- Test: `tests/testthat/test-plot-processed-curves.R` (new)

- [ ] **Step 1: Write the failing test**

Create `tests/testthat/test-plot-processed-curves.R`:
```r
test_that("plot_processed_curves uses a log10 y-axis", {
  obj <- create_curated_test_object()
  obj <- transform_curated_data(obj)
  p <- plot_processed_curves(obj)

  expect_s3_class(p, "ggplot")

  y_scale <- p$scales$scales[[which(vapply(
    p$scales$scales, function(s) "y" %in% s$aesthetics, logical(1)
  ))]]
  expect_equal(y_scale$trans$name, "log-10")
  expect_match(p$labels$y, "log10", ignore.case = TRUE)
})
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
Rscript -e "testthat::test_file('tests/testthat/test-plot-processed-curves.R')"
```
Expected: FAIL — the plot currently has a continuous linear y scale (`trans$name` is `"identity"`) and y label is `"Optical Density (OD)"`.

- [ ] **Step 3: Apply log10 scale + rename label**

In `R/plot-processed-curves.R`, replace the ggplot chain (lines 23-32) with:
```r
  p <- ggplot2::ggplot(plot_df, ggplot2::aes(x = time, y = od, group = SampleID, color = factor(group_id))) +
    ggplot2::geom_line(alpha = 0.7) +
    viridis::scale_color_viridis(discrete = TRUE, name = "Exp. Group") +
    ggplot2::scale_y_log10(n.breaks = 8) +
    ggplot2::labs(
      title = "Pre-processed Growth Curves",
      subtitle = "Each line represents a consortium averaged across its replicates.",
      x = "Time (seconds)",
      y = "Optical Density (OD, log10)"
    ) +
    ggplot2::theme_minimal()
```

- [ ] **Step 4: Run test to verify it passes**

Run:
```bash
Rscript -e "testthat::test_file('tests/testthat/test-plot-processed-curves.R')"
```
Expected: PASS.

- [ ] **Step 5: Commit**

Run:
```bash
git add R/plot-processed-curves.R tests/testthat/test-plot-processed-curves.R
git commit -m "feat(plot_processed_curves): log10 y-axis with fine ticks"
```

---

### Task A3: Remove Top-k path and rename axis in `analyze_diversity`

**Files:**
- Modify: `R/analyze-diversity.R` (delete lines ~103-157; keep lines 11-101 with one label change)
- Modify: `tests/testthat/test-analyze-diversity.R`

- [ ] **Step 1: Update test to reflect the removed slots and new label**

Replace `tests/testthat/test-analyze-diversity.R` entire content with:
```r
test_that("analyze_diversity creates diversity plots and tables", {
  obj <- create_curated_test_object()
  obj <- transform_curated_data(obj)
  obj <- analyze_social_behavior(obj)
  obj <- analyze_diversity(obj)

  expect_true(!is.null(obj@graficos$diversity_gen_plot))
  expect_s3_class(obj@graficos$diversity_gen_plot, "ggplot")
  expect_true(!is.null(obj@resultados_analisis$diversity_gen_table))
})

test_that("analyze_diversity no longer produces Top-k slots", {
  obj <- create_curated_test_object()
  obj <- transform_curated_data(obj)
  obj <- analyze_social_behavior(obj)
  obj <- analyze_diversity(obj)

  expect_null(obj@resultados_analisis$diversity_best_gen_table)
  expect_null(obj@resultados_analisis$diversity_best_gr_table)
  expect_null(obj@graficos$diversity_best_gen_plot)
  expect_null(obj@graficos$diversity_best_gr_plot)
})

test_that("diversity boxplot x-axis reads 'Species richness in consortium'", {
  obj <- create_curated_test_object()
  obj <- transform_curated_data(obj)
  obj <- analyze_social_behavior(obj)
  obj <- analyze_diversity(obj)

  p <- obj@graficos$diversity_gen_plot
  expect_equal(p$labels$x, "Species richness in consortium")
})
```

- [ ] **Step 2: Run tests to verify the new ones fail**

Run:
```bash
Rscript -e "testthat::test_file('tests/testthat/test-analyze-diversity.R')"
```
Expected: First test PASSES; second test FAILS (slots still populated); third test FAILS (label is "Number of strains in consortium").

- [ ] **Step 3: Edit `R/analyze-diversity.R`**

Apply three changes:

**Change 1** — line 89 (in `plot_diversity_boxplot` helper): rename axis label.

Replace:
```r
      ggplot2::labs(x = "Number of strains in consortium", y = ylab, fill = "Diversity") +
```

With:
```r
      ggplot2::labs(x = "Species richness in consortium", y = ylab, fill = "Diversity") +
```

**Change 2** — empty fallback branch, lines 56-57 and 65-66: remove the four empty-state best slots.

Delete these four lines:
```r
    .Object@resultados_analisis$diversity_best_gen_table <- empty
    .Object@resultados_analisis$diversity_best_gr_table  <- empty
```
And:
```r
    .Object@graficos$diversity_best_gen_plot <- .Object@graficos$diversity_gen_plot
    .Object@graficos$diversity_best_gr_plot  <- .Object@graficos$diversity_gen_plot
```

**Change 3** — delete the Top-k block, lines 103-157: remove `rank_strains()`, `build_best_matrix()`, `plot_best_boxplot()` and all their call sites. The function should end after line 101 (the `.Object@graficos$diversity_gr_plot <- plot_diversity_boxplot(...)` line) with `.Object` on a new line.

After edits, the tail of the function should look like:
```r
  .Object@graficos$diversity_gen_plot <- plot_diversity_boxplot(div_gen, "Relative Fitness (Generations)")
  .Object@graficos$diversity_gr_plot  <- plot_diversity_boxplot(div_gr,  "Relative Fitness (Growth Rate)")

  .Object
})
```

- [ ] **Step 4: Run tests to verify all pass**

Run:
```bash
Rscript -e "testthat::test_file('tests/testthat/test-analyze-diversity.R')"
```
Expected: All three tests PASS.

- [ ] **Step 5: Commit**

Run:
```bash
git add R/analyze-diversity.R tests/testthat/test-analyze-diversity.R
git commit -m "refactor(analyze_diversity): remove Top-k path, rename x-axis to species richness"
```

---

### Task A4: Extract `generate_social_plot` helper to file scope

Pure refactor — existing tests must keep passing unchanged. We lift the inner `generate_social_plot` function out of `analyze_social_behavior()`'s body so it can be called later from `summarize_social_behavior()` when classification is available.

**Files:**
- Modify: `R/analyze-social-behavior.R` (move inner helper to top of file; adjust call sites).

- [ ] **Step 1: Add the `stats_tbl` parameter to the helper and lift it out of the method**

In `R/analyze-social-behavior.R`, **before** the `setMethod("analyze_social_behavior", ...)` line, insert this top-level helper:

```r
# Internal helper: builds the faceted social behavior boxplot.
# When `stats_tbl` is non-NULL, draws Cooperator/Cheater/Neutral badges
# below each facet.
generate_social_plot <- function(data_boxplot, cepas, tipo, ylab, stats_tbl = NULL) {
  nr <- nrow(data_boxplot)
  nc <- length(cepas)

  if (nr == 0 || ncol(data_boxplot) == 0) {
    return(
      ggplot2::ggplot() +
        ggplot2::annotate("text", x = 0.5, y = 0.5,
                          label = "Insufficient data for boxplot", size = 4) +
        ggplot2::theme_void()
    )
  }

  labels <- c("all / monoculture", "not present / monoculture", "present / monoculture")

  mx <- suppressMessages(
    reshape2::melt(data_boxplot, measure.vars = colnames(data_boxplot))
  )
  mx$type <- rep(rep(labels, each = nr), times = nc)
  mx$pos  <- rep(cepas, each = nr * 3)
  mx <- mx[!is.na(mx$value) & is.finite(mx$value), , drop = FALSE]

  if (nrow(mx) == 0) {
    return(
      ggplot2::ggplot() +
        ggplot2::annotate("text", x = 0.5, y = 0.5,
                          label = "Insufficient data for boxplot", size = 4) +
        ggplot2::theme_void()
    )
  }

  p <- ggplot2::ggplot(mx, ggplot2::aes(x = type, y = value, fill = type)) +
    ggplot2::geom_boxplot(na.rm = TRUE) +
    ggplot2::facet_grid(. ~ pos) +
    ggplot2::labs(x = NULL, y = ylab, title = tipo) +
    ggplot2::theme(
      axis.text.x = ggplot2::element_blank(),
      axis.ticks.x = ggplot2::element_blank(),
      plot.margin = ggplot2::margin(5, 5, 25, 5)
    )

  if (!is.null(stats_tbl) && nrow(stats_tbl) > 0) {
    badge_df <- data.frame(
      pos   = stats_tbl$strain,
      label = stats_tbl$classification,
      type  = "not present / monoculture",
      value = -Inf,
      stringsAsFactors = FALSE
    )
    badge_df <- badge_df[badge_df$pos %in% unique(mx$pos), , drop = FALSE]
    color_map <- c(Cooperator = "#2e7d32", Cheater = "#c62828", Neutral = "#616161")

    p <- p +
      ggplot2::geom_text(
        data = badge_df,
        ggplot2::aes(x = type, y = value, label = label, color = label),
        vjust = 1.8, fontface = "bold", size = 3.5, show.legend = FALSE,
        inherit.aes = FALSE
      ) +
      ggplot2::scale_color_manual(values = color_map) +
      ggplot2::coord_cartesian(clip = "off")
  }

  p
}
```

- [ ] **Step 2: Remove the inner function definition and its two call sites inside the method**

Inside `setMethod("analyze_social_behavior", ...)` in the same file:

1. Delete the inner `generate_social_plot <- function(...) { ... }` block (originally lines 64-105 of the old file).
2. Update the two call sites (originally lines 107-108) to pass `stats_tbl = NULL` so the method keeps its prior behavior (no badges at this stage of the pipeline):

```r
  plot_gen <- generate_social_plot(data_gen, cepas, "Fitness over number of generations", "Fitness (NGen)", stats_tbl = NULL)
  plot_gr  <- generate_social_plot(data_gr,  cepas, "Fitness over growth rate",             "Fitness (GR)",   stats_tbl = NULL)
```

- [ ] **Step 3: Run the existing test suite — behavior is unchanged**

Run:
```bash
Rscript -e "testthat::test_file('tests/testthat/test-analyze-social-behavior.R')"
```
Expected: PASS, with no change from before.

- [ ] **Step 4: Commit**

Run:
```bash
git add R/analyze-social-behavior.R
git commit -m "refactor(analyze_social_behavior): lift generate_social_plot helper to file scope"
```

---

### Task A5: Stats tables + rebuilt plots with badges in `summarize_social_behavior`

**Files:**
- Modify: `R/summarize-social-behavior.R:10-161` (largely rewritten)
- Modify: `tests/testthat/test-summarize-social-behavior.R`

- [ ] **Step 1: Write the failing tests**

Append to `tests/testthat/test-summarize-social-behavior.R`:
```r
test_that("summarize_social_behavior stores per-strain stats tables", {
  obj <- create_curated_test_object()
  obj <- transform_curated_data(obj)
  obj <- analyze_social_behavior(obj)

  skip_if(!obj@resultados_analisis$social_behavior$success,
          "Social behavior analysis did not succeed with example data")

  obj <- summarize_social_behavior(obj)

  for (slot_name in c("stats_gen", "stats_gr")) {
    tbl <- obj@resultados_analisis[[slot_name]]
    expect_s3_class(tbl, "data.frame")
    expect_setequal(
      colnames(tbl),
      c("strain", "median_all", "median_not", "median_present",
        "p_all_vs_not", "p_all_vs_pres", "p_not_vs_pres", "classification")
    )
    expect_equal(nrow(tbl), length(obj@cepas_seleccionadas))
    expect_true(all(tbl$classification %in% c("Cooperator", "Cheater", "Neutral")))
  }
})

test_that("summarize_social_behavior rebuilds social plots with badge layers", {
  obj <- create_curated_test_object()
  obj <- transform_curated_data(obj)
  obj <- analyze_social_behavior(obj)

  skip_if(!obj@resultados_analisis$social_behavior$success,
          "Social behavior analysis did not succeed with example data")

  obj <- summarize_social_behavior(obj)

  p_gen <- obj@resultados_analisis$social_behavior$social_generations_plot
  p_gr  <- obj@resultados_analisis$social_behavior$social_gr_plot

  has_text_layer <- function(p) {
    any(vapply(p$layers, function(l) inherits(l$geom, "GeomText"), logical(1)))
  }

  expect_true(has_text_layer(p_gen))
  expect_true(has_text_layer(p_gr))
})
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
Rscript -e "testthat::test_file('tests/testthat/test-summarize-social-behavior.R')"
```
Expected: FAIL — stats tables missing, plots have no GeomText layer.

- [ ] **Step 3: Refactor `summarize_one_metric` to return a list with `positives`, `negatives`, `neutrals`, and `stats`**

In `R/summarize-social-behavior.R`, replace the entire `summarize_one_metric` function body (lines 28-152) with:

```r
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

    nr <- nrow(data_for_boxplot)

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
      # Matrix rows/cols (alphabetical after stripping the "<strain>_" prefix):
      # rownames: NotPresent, Present ; colnames: ALL, NotPresent
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
```

- [ ] **Step 4: Update the method body to store stats and rebuild plots**

Replace the early-return empty branch (original lines 15-23) with a richer empty state:
```r
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
      median_all     = NA_real_, median_not = NA_real_, median_present = NA_real_,
      p_all_vs_not   = NA_real_, p_all_vs_pres = NA_real_, p_not_vs_pres = NA_real_,
      classification = rep("Neutral", nstrains),
      stringsAsFactors = FALSE
    )
    .Object@resultados_analisis$summary_gen <- empty_lists
    .Object@resultados_analisis$summary_gr  <- empty_lists
    .Object@resultados_analisis$stats_gen   <- empty_stats
    .Object@resultados_analisis$stats_gr    <- empty_stats
    return(.Object)
  }
```

Replace the tail of the method (original lines 154-161) with:
```r
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
```

- [ ] **Step 5: Run the whole social-behavior test subset**

Run:
```bash
Rscript -e "testthat::test_file('tests/testthat/test-summarize-social-behavior.R'); testthat::test_file('tests/testthat/test-analyze-social-behavior.R')"
```
Expected: All tests PASS.

- [ ] **Step 6: Commit**

Run:
```bash
git add R/summarize-social-behavior.R tests/testthat/test-summarize-social-behavior.R
git commit -m "feat(summarize_social_behavior): expose stats tables and rebuild plots with badges"
```

---

### Task A6: New `plot_growth_scatter` + refactor `analyze_growth`

**Files:**
- Create: `R/plot-growth-scatter.R`
- Modify: `R/bsocial-class.R` (add generic)
- Modify: `R/analyze-growth.R:31-41`
- Modify: `DESCRIPTION` (add `R/plot-growth-scatter.R` to Collate)
- Modify: `tests/testthat/test-analyze-growth.R`
- Test: `tests/testthat/test-plot-growth-scatter.R` (new)

- [ ] **Step 1: Write the failing tests**

Create `tests/testthat/test-plot-growth-scatter.R`:
```r
test_that("plot_growth_scatter returns a ggplot from datos_procesados", {
  obj <- create_curated_test_object()
  obj <- transform_curated_data(obj)

  p <- plot_growth_scatter(obj)
  expect_s3_class(p, "ggplot")
})

test_that("plot_growth_scatter with remove_outliers=TRUE filters high points using IQR", {
  obj <- create_curated_test_object()
  obj <- transform_curated_data(obj)

  # Inject an artificial outlier so the IQR rule has something to catch
  obj@datos_procesados$LogPhase[1] <- max(obj@datos_procesados$LogPhase, na.rm = TRUE) * 10
  obj@datos_procesados$NGen[1]     <- max(obj@datos_procesados$NGen,     na.rm = TRUE) * 10

  p_all  <- plot_growth_scatter(obj, remove_outliers = FALSE)
  p_filt <- plot_growth_scatter(obj, remove_outliers = TRUE)

  expect_lt(nrow(p_filt$data), nrow(p_all$data))
  expect_match(p_filt$labels$subtitle %||% "", "hidden", ignore.case = TRUE)
})
```

Also update `tests/testthat/test-analyze-growth.R`:
```r
test_that("analyze_growth creates scatter plot and top-10 tables", {
  obj <- create_curated_test_object()
  obj <- transform_curated_data(obj)
  obj <- analyze_growth(obj)

  expect_true(!is.null(obj@graficos$growth_scatter))
  expect_s3_class(obj@graficos$growth_scatter, "ggplot")
  expect_true(!is.null(obj@resultados_analisis$best_10_ngen))
  expect_true(!is.null(obj@resultados_analisis$best_10_gr))
})

test_that("analyze_growth delegates plotting to plot_growth_scatter (no outliers removed by default)", {
  obj <- create_curated_test_object()
  obj <- transform_curated_data(obj)
  obj <- analyze_growth(obj)

  cached <- obj@graficos$growth_scatter
  fresh  <- plot_growth_scatter(obj, remove_outliers = FALSE)

  expect_equal(nrow(cached$data), nrow(fresh$data))
})
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
Rscript -e "testthat::test_file('tests/testthat/test-plot-growth-scatter.R')"
```
Expected: FAIL — `plot_growth_scatter` does not exist.

- [ ] **Step 3: Create the new file `R/plot-growth-scatter.R`**

```r
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
#' @export
setGeneric("plot_growth_scatter", function(.Object, remove_outliers = FALSE, outlier_coef = 1.5) {
  standardGeneric("plot_growth_scatter")
})

#' @rdname plot_growth_scatter
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
```

- [ ] **Step 4: Add to `DESCRIPTION` Collate**

In `DESCRIPTION`, add `'plot-growth-scatter.R'` after `'plot-processed-curves.R'` and before `'analyze-growth.R'`:
```
Collate:
    'bsocial-package.R'
    'bsocial-log.R'
    'bsocial-class.R'
    'transform-raw-data.R'
    'transform-curated-data.R'
    'calculate-growth-params.R'
    'plot-processed-curves.R'
    'plot-growth-scatter.R'
    'analyze-growth.R'
    'analyze-social-behavior.R'
    'summarize-social-behavior.R'
    'analyze-diversity.R'
    'analyze-biofilm-sequence.R'
    'analyze-stability.R'
```

- [ ] **Step 5: Refactor `analyze_growth` to delegate plotting**

In `R/analyze-growth.R`, replace lines 31-41 (the `scatter_plot <- ggplot2::ggplot(...) ... .Object@graficos$growth_scatter <- scatter_plot`) with:
```r
  .Object@graficos$growth_scatter <- plot_growth_scatter(.Object, remove_outliers = FALSE)
```

- [ ] **Step 6: Run tests to verify all pass**

Run:
```bash
Rscript -e "devtools::load_all(); testthat::test_file('tests/testthat/test-plot-growth-scatter.R'); testthat::test_file('tests/testthat/test-analyze-growth.R')"
```
Expected: All four tests PASS.

- [ ] **Step 7: Commit**

Run:
```bash
git add R/plot-growth-scatter.R R/analyze-growth.R DESCRIPTION tests/testthat/test-plot-growth-scatter.R tests/testthat/test-analyze-growth.R
git commit -m "feat(plot_growth_scatter): new on-demand scatter with IQR outlier toggle"
```

---

### Task A7: Regenerate docs, bump version, update NEWS

**Files:**
- Modify: `DESCRIPTION`
- Modify: `NEWS.md`
- Modify: `NAMESPACE` (auto-regenerated)
- Create: `man/plot_growth_scatter.Rd` (auto-regenerated)

- [ ] **Step 1: Bump `DESCRIPTION` version**

Change:
```
Version: 0.1.1
```
To:
```
Version: 0.2.0
```

- [ ] **Step 2: Prepend a new entry to `NEWS.md`**

Replace the content of `NEWS.md` with:
```markdown
# bsocialv2 0.2.0

## Breaking changes

* `analyze_diversity()` no longer produces `diversity_best_gen_plot`,
  `diversity_best_gr_plot`, `diversity_best_gen_table`,
  `diversity_best_gr_table`. The Top-k strains ranking path has been
  removed; use the per-diversity-level plots instead.

## New features

* New exported function `plot_growth_scatter(.Object, remove_outliers, outlier_coef)`
  renders the LogPhase-vs-NGen scatter on demand. When `remove_outliers = TRUE`,
  points above the Tukey IQR threshold in either axis are hidden and a subtitle
  reports the hidden count.
* `plot_processed_curves()` now draws the y-axis on a log10 scale with fine
  breaks. Non-positive OD values are dropped (consistent with the log transform).
* Per-strain cooperator/cheater/neutral badges are drawn below each facet in
  the plots produced by `analyze_social_behavior()` when
  `summarize_social_behavior()` has run.
* `summarize_social_behavior()` now stores `stats_gen` and `stats_gr` data frames
  in `@resultados_analisis`, containing per-strain medians, pairwise t-test
  p-values, and classification label.

## Minor improvements

* `analyze_diversity()` x-axis label changed to "Species richness in consortium".

# bsocialv2 0.1.0

* Initial CRAN release.
* S4 class `bsocial` with six slots for organizing consortia analysis data.
* Growth parameter extraction via growthcurver (grofit available as optional backend).
* Social behavior classification: cooperators, cheaters, and neutrals.
* Diversity effect analysis relating consortium richness to fitness.
* Stability analysis via coefficient of variation across replicates.
* Biofilm assembly sequence finding using igraph shortest paths.
* Two workflow paths: raw plate reader data or pre-processed (curated) parameters.
```

- [ ] **Step 3: Regenerate documentation and NAMESPACE**

Run:
```bash
Rscript -e "devtools::document()"
```
Expected: `man/plot_growth_scatter.Rd` is created; `NAMESPACE` gains `export(plot_growth_scatter)` and `exportMethods(plot_growth_scatter)`.

- [ ] **Step 4: Run the full test suite**

Run:
```bash
Rscript -e "devtools::test()"
```
Expected: All tests pass (including the new ones).

- [ ] **Step 5: Run `devtools::check()`**

Run:
```bash
Rscript -e "devtools::check(args = '--no-manual')"
```
Expected: `0 errors, 0 warnings, 0 notes` (or at most NOTEs pre-existing before this work — compare to a pre-change run if in doubt).

If errors appear, fix them in place. Common issues:
- Missing `@return` in a new roxygen block — add one.
- Missing import for a function newly used — add `#' @importFrom` or declare in `NAMESPACE` via roxygen.
- Unused import for code you deleted — remove from `NAMESPACE`.

- [ ] **Step 6: Commit**

Run:
```bash
git add DESCRIPTION NEWS.md NAMESPACE man/
git commit -m "chore: bump to 0.2.0, update docs and NEWS"
```

---

### Task A8: Merge feature branch and push to `main`

This is a destructive-ish shared-state action. **Only run after user confirmation.**

- [ ] **Step 1: Confirm the branch is clean and green**

Run:
```bash
git status
Rscript -e "devtools::test()"
```
Expected: clean working tree, all tests pass.

- [ ] **Step 2: Check out `main` and fast-forward merge**

Run:
```bash
git checkout main
git merge --ff-only feature/ui-package-updates-v0.2.0
```
If fast-forward fails (main moved), rebase the feature branch first:
```bash
git checkout feature/ui-package-updates-v0.2.0
git rebase main
git checkout main
git merge --ff-only feature/ui-package-updates-v0.2.0
```

- [ ] **Step 3: Push to origin**

Run:
```bash
git push origin main
```

- [ ] **Step 4: Record the new commit SHA**

Run:
```bash
git rev-parse HEAD
```
Copy the SHA — you'll need it implicitly when `renv::update()` runs in Phase B.

---

## Phase B — App changes (`BSocialApp`)

### Task B1: Feature branch in `BSocialApp` and update `renv.lock`

**Files:**
- Modify: `renv.lock`

- [ ] **Step 1: Switch repos and create branch**

Run:
```bash
cd 'C:\Users\juane\Documents\GitHub\BSocialApp'
git checkout main
git pull
git checkout -b feature/ui-package-updates-v0.2.0
```

- [ ] **Step 2: Update `bsocialv2` in renv**

Run:
```bash
Rscript -e "renv::update('bsocialv2')"
```
Expected: `renv.lock` is updated with the new SHA and `Version: 0.2.0`.

- [ ] **Step 3: Verify the update landed**

Run:
```bash
Rscript -e "cat(jsonlite::read_json('renv.lock')\$Packages\$bsocialv2\$Version, '\n')"
```
Expected: `0.2.0`.

- [ ] **Step 4: Commit the lockfile**

Run:
```bash
git add renv.lock
git commit -m "chore(renv): bump bsocialv2 to 0.2.0"
```

---

### Task B2: Outlier checkbox in `mod_crecimiento`

**Files:**
- Modify: `R/mod_crecimiento.R:42-47` (UI) and `R/mod_crecimiento.R:70-73` (reactive).

- [ ] **Step 1: Add the checkbox to the UI**

In `R/mod_crecimiento.R`, replace the `section-title-row` block (lines 42-46):
```r
        tags$div(class = "section-title-row",
          h4("Scatter Plot (Log Phase vs. Generations)"),
          downloadButton(ns("download_plot"), "PDF", class = "btn-sm btn-outline-secondary")
        ),
```

With:
```r
        tags$div(class = "section-title-row",
          h4("Scatter Plot (Log Phase vs. Generations)"),
          tags$div(style = "display:flex; gap:12px; align-items:center;",
            checkboxInput(ns("hide_outliers"), "Hide outliers (IQR)", value = FALSE, width = "auto"),
            downloadButton(ns("download_plot"), "PDF", class = "btn-sm btn-outline-secondary")
          )
        ),
```

- [ ] **Step 2: Replace the cached reactive with an on-demand call**

In the same file, replace lines 70-73:
```r
    plot_to_show <- eventReactive(bsocial_object(), {
      req(bsocial_object()@graficos$growth_scatter)
      bsocial_object()@graficos$growth_scatter
    })
```

With:
```r
    plot_to_show <- reactive({
      req(bsocial_object())
      req(bsocial_object()@datos_procesados)
      bsocialv2::plot_growth_scatter(bsocial_object(), remove_outliers = isTRUE(input$hide_outliers))
    })
```

- [ ] **Step 3: Commit**

Run:
```bash
git add R/mod_crecimiento.R
git commit -m "feat(mod_crecimiento): IQR outlier checkbox drives reactive scatter"
```

---

### Task B3: Statistics sub-tab in `mod_comportamiento`

**Files:**
- Modify: `R/mod_comportamiento.R:62-88` (UI navset) and the server body.

- [ ] **Step 1: Add the "Statistics" sub-tab to the navset**

In `R/mod_comportamiento.R`, replace the `bslib::navset_card_tab(...)` block (lines 63-79) with the following three-panel version:

```r
        bslib::navset_card_tab(
          bslib::nav_panel(
            "Number of Generations",
            tags$div(class = "section-title-row",
              h4("Relative Fitness Analysis (NGen)"),
              downloadButton(ns("download_plot_gen"), "PDF", class = "btn-sm btn-outline-secondary")
            ),
            plotOutput(ns("social_plot_generations"), height = "550px")
          ),
          bslib::nav_panel(
            "Growth Rate",
            tags$div(class = "section-title-row",
              h4("Relative Fitness Analysis (GR)"),
              downloadButton(ns("download_plot_gr"), "PDF", class = "btn-sm btn-outline-secondary")
            ),
            plotOutput(ns("social_plot_gr"), height = "550px")
          ),
          bslib::nav_panel(
            "Statistics",
            tags$div(class = "section-title-row",
              h4("Per-strain statistics (NGen & GR)"),
              downloadButton(ns("download_stats_csv"), "CSV", class = "btn-sm btn-outline-secondary")
            ),
            DT::dataTableOutput(ns("stats_table"))
          )
        ),
```

- [ ] **Step 2: Add the reactive + output + download handler**

In `R/mod_comportamiento.R`, just before the existing `output$download_plot_gen <- downloadHandler(` (around line 98), add:

```r
    stats_combined <- reactive({
      obj <- bsocial_object()
      req(obj@resultados_analisis$stats_gen, obj@resultados_analisis$stats_gr)
      g <- obj@resultados_analisis$stats_gen; g$metric <- "NGen"
      r <- obj@resultados_analisis$stats_gr;  r$metric <- "GR"
      rbind(g, r)[, c("metric", "strain", "median_all", "median_not", "median_present",
                      "p_all_vs_not", "p_all_vs_pres", "p_not_vs_pres", "classification")]
    })

    output$stats_table <- DT::renderDataTable({
      DT::datatable(
        stats_combined(),
        options = list(scrollX = TRUE, pageLength = 20),
        rownames = FALSE
      )
    })

    output$download_stats_csv <- downloadHandler(
      filename = function() {
        proj <- bsocial_object()@id_proyecto
        if (is.null(proj) || !nzchar(proj)) proj <- "bsocial"
        paste0(proj, "_social_stats_", Sys.Date(), ".csv")
      },
      content = function(file) {
        write.csv(stats_combined(), file, row.names = FALSE)
      }
    )
```

- [ ] **Step 3: Commit**

Run:
```bash
git add R/mod_comportamiento.R
git commit -m "feat(mod_comportamiento): add Statistics sub-tab with CSV download"
```

---

### Task B4: Remove Top-k panel and section from `mod_diversidad`

**Files:**
- Modify: `R/mod_diversidad.R` (sections inside `renderUI`, the `results()` reactive, outputs and download handlers).

- [ ] **Step 1: Remove the "Best Strains (Top-k)" `nav_panel`**

In `R/mod_diversidad.R`, delete the entire block at lines 62-79:
```r
        bslib::nav_panel(
          "Best Strains (Top-k)",
          fluidRow(
            column(6,
              ...
              plotOutput(ns("plot_best_gen"))
            ),
            column(6,
              ...
              plotOutput(ns("plot_best_gr"))
            )
          )
        ),
```

- [ ] **Step 2: Remove section B) inside the "Data" `nav_panel`**

In the "Data" panel (currently starting at line 81), delete from `hr(),` (line 100) through the end of section B's `fluidRow` (line 117). The panel body should end with the first `fluidRow` (section A), closed by `)` that ends `nav_panel("Data", ...)`.

After the edit, the Data panel looks like:
```r
        bslib::nav_panel(
          "Data",
          h5("A) Relative fitness by diversity (number of strains in consortium)"),
          fluidRow(
            column(6,
              tags$div(class = "section-title-row",
                h6("Generations"),
                downloadButton(ns("download_table_gen"), "CSV", class = "btn-sm btn-outline-secondary")
              ),
              DT::dataTableOutput(ns("diversity_table_gen"))
            ),
            column(6,
              tags$div(class = "section-title-row",
                h6("Growth Rate"),
                downloadButton(ns("download_table_gr"), "CSV", class = "btn-sm btn-outline-secondary")
              ),
              DT::dataTableOutput(ns("diversity_table_gr"))
            )
          )
        )
```

- [ ] **Step 3: Drop `plot_best_*` and `table_best_*` from the `results()` reactive**

Replace the `results` block at lines 122-135 with:
```r
    results <- eventReactive(bsocial_object(), {
      req(bsocial_object()@graficos$diversity_gen_plot)
      obj <- bsocial_object()
      list(
        plot_gen  = obj@graficos$diversity_gen_plot,
        plot_gr   = obj@graficos$diversity_gr_plot,
        table_gen = obj@resultados_analisis$diversity_gen_table,
        table_gr  = obj@resultados_analisis$diversity_gr_table
      )
    })
```

- [ ] **Step 4: Remove the four dead outputs**

Delete these four lines:
```r
    output$plot_best_gen <- renderPlot({ results()$plot_best_gen })
    output$plot_best_gr  <- renderPlot({ results()$plot_best_gr })
    output$diversity_table_best_gen <- DT::renderDataTable({ ... })
    output$diversity_table_best_gr  <- DT::renderDataTable({ ... })
```

- [ ] **Step 5: Remove the four dead download handlers**

Delete the four `downloadHandler` blocks tied to `download_plot_best_gen`, `download_plot_best_gr`, `download_table_best_gen`, `download_table_best_gr` (currently lines 171-178 and 187-193).

- [ ] **Step 6: Commit**

Run:
```bash
git add R/mod_diversidad.R
git commit -m "refactor(mod_diversidad): remove Top-k panel and section"
```

---

### Task B5: Local smoke test

**Files:**
- None. Manual verification only.

- [ ] **Step 1: Start the app locally**

Run:
```bash
Rscript -e "pkgload::load_all(); BSocialApp::run_app()"
```
Expected: browser opens to the Shiny app.

- [ ] **Step 2: Run this checklist**

Load a test project (curated or raw — both should work if the bsocialv2 test fixtures are available).

- **Raw Curves tab**: y-axis shows log10 scale with ~8 tick marks; axis label reads "Optical Density (OD, log10)".
- **Growth tab**:
  - Scatter plot renders.
  - Toggle "Hide outliers (IQR)" — points disappear/reappear, subtitle shows hidden count when enabled.
  - PDF download respects the current toggle state.
- **Social tab**:
  - "Number of Generations" sub-tab: below each strain facet there is a colored badge reading `Cooperator` / `Cheater` / `Neutral`.
  - "Growth Rate" sub-tab: same badges, but their values may differ (per-metric classification).
  - **New** "Statistics" sub-tab exists; table has columns `metric, strain, median_*, p_*, classification`; CSV download works and the downloaded file opens cleanly.
- **Diversity tab**:
  - Only two sub-tabs: "Diversity vs Fitness" and "Data".
  - "Data" sub-tab shows only section A, no section B.
  - Boxplot x-axis reads "Species richness in consortium".

Any failure here means the relevant task in Phase B needs a fix — return to that task.

- [ ] **Step 3: Stop the app**

Ctrl+C in the R process (or close the browser and let `run_app` exit).

---

### Task B6: Push app branch and merge to `main`

**Only run after Task B5 is fully green and confirmed by the user.**

- [ ] **Step 1: Merge and push**

Run:
```bash
git checkout main
git merge --ff-only feature/ui-package-updates-v0.2.0
git push origin main
```

---

### Task B7: Deploy to shinyapps.io

**Shared-state destructive action. Only run after user confirmation.**

- [ ] **Step 1: Deploy**

Run:
```bash
Rscript -e "rsconnect::deployApp(appDir = '.', forceUpdate = TRUE)"
```
Expected: a build log streams and ends with a URL to the deployed app.

- [ ] **Step 2: Smoke check the deployed app**

Open the returned URL in a browser and re-run the Task B5 checklist. If anything is off, investigate `rsconnect::showLogs()` and redeploy after fixes.

---

## Appendix — Rollback notes

- **Package rollback:** `git revert <merge-commit>` on `bsocialv2` main, push; then in app `renv::update('bsocialv2')` to re-pin to the pre-0.2.0 SHA.
- **App rollback:** previous shinyapps.io deployment is kept on the platform; revert the app main commit and redeploy.
