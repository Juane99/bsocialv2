# bsocialv2 + BSocialApp — UI and Package Updates

**Date:** 2026-04-20
**Affected repos:** `bsocialv2` (R package), `BSocialApp` (Shiny companion)
**Target package version:** `bsocialv2 0.2.0` (bump from `0.1.1`; contains a breaking change to `analyze_diversity` output).

## Goal

Apply six user-requested improvements that span both the R package and its Shiny UI:

1. Growth curves plot uses a log10 y-axis with fine ticks.
2. Growth scatter plot (LogPhase vs NGen) offers outlier hiding via IQR rule — a package parameter and a UI checkbox.
3. Social behavior plot annotates each strain facet with its classification (cooperator / cheater / neutral).
4. Social tab gains a new "Statistics" sub-tab with a downloadable table covering both metrics.
5. Diversity tab drops the "Best Strains (Top-k)" sub-tab and the associated code path in the package.
6. Diversity x-axis label: "Number of strains in consortium" → "Species richness in consortium".

## Non-goals

- No change to raw/curated ingestion, preprocessing logic, or growth curve fitting.
- No change to the Stability or Biofilm tabs.
- No new statistical methods — only surfacing what `summarize_social_behavior()` already computes.
- No change to the "Num. strains" legend in the Growth scatter plot or to the `n_cepas` → `"Num Strains"` mapping in the Stability tab (those remain).

## Architectural decisions

**Separate analysis from rendering for the scatter.** Today `analyze_growth()` both computes top-10 tables and produces the scatter plot, caching it in `@graficos$growth_scatter`. To make the UI checkbox reactive without re-running the analysis, we move plot generation to a new exported function `plot_growth_scatter()` that takes the object and a flag. `analyze_growth()` still populates the cached slot by calling the new function with `remove_outliers = FALSE` — backward compatible.

**Badge inside the package, not the app.** The cooperator/cheater/neutral classification lives in `summarize_social_behavior()`. Adding the badge inside `analyze_social_behavior()` (after `summarize_social_behavior()` has run) keeps the plot self-contained: the app renders whatever ggplot the package returns, as today.

**Per-metric classification.** A strain may be cooperator by NGen and neutral by GR. The package already treats these as separate analyses (`summary_gen` vs `summary_gr`). Badges and stats tables follow that split.

**Leave CRAN-shipped API untouched where possible, but accept one breaking change.** Removing `diversity_best_*` slots from `analyze_diversity()` output is a breaking change. It is contained to a sub-analysis whose only consumer is the UI, so impact outside this ecosystem is minimal. It goes in `NEWS.md` and justifies the 0.2.0 bump.

## Package changes (`bsocialv2`)

### 1. `R/plot-processed-curves.R` — log10 y-axis

- Add `ggplot2::scale_y_log10(breaks = scales::breaks_log(n = 8), minor_breaks = scales::breaks_log(n = 20))` to the plot chain.
- Change y-axis label to `"Optical Density (OD, log10)"`.
- Always on, no new parameter. Non-positive OD values are dropped with a warning (inherent to `scale_y_log10`) — documented in `NEWS.md`.

### 2. `R/plot-growth-scatter.R` (new) + refactor `R/analyze-growth.R`

- New exported S4 method:

  ```r
  setGeneric("plot_growth_scatter", function(.Object, remove_outliers = FALSE, outlier_coef = 1.5) standardGeneric("plot_growth_scatter"))
  setMethod("plot_growth_scatter", "bsocial", function(.Object, remove_outliers = FALSE, outlier_coef = 1.5) {
    df <- .Object@datos_procesados  # precondition checked
    if (remove_outliers) {
      q <- function(x) stats::quantile(x, c(0.25, 0.75), na.rm = TRUE)
      lp <- q(df$LogPhase); ng <- q(df$NGen)
      keep <- df$LogPhase <= lp[2] + outlier_coef * diff(lp) &
              df$NGen     <= ng[2] + outlier_coef * diff(ng)
      hidden <- sum(!keep, na.rm = TRUE)
      df <- df[keep, , drop = FALSE]
    }
    # ...ggplot construction (same as current analyze_growth), plus subtitle
    # "N consortia hidden (IQR rule)" when remove_outliers = TRUE
  })
  ```

- `analyze_growth()` stops building the plot inline; it calls `plot_growth_scatter(.Object, FALSE)` and stores the result in `@graficos$growth_scatter` as before. Top-10 tables computation is unchanged.
- Export `plot_growth_scatter` in `NAMESPACE`. Add generic declaration (likely next to `plot_processed_curves` generic).
- Add roxygen block producing `man/plot_growth_scatter.Rd`.

### 3. `R/summarize-social-behavior.R` — expose stats tables

Currently the function computes medians and per-strain pairwise p-values from `stats::pairwise.t.test()` over the three treatment levels (`ALL`, `NotPresent`, `Present` — all already normalized to monoculture), then stores only classification vectors. Extend it to also save structured tables.

The `pairwise.t.test` output matrix (with levels alphabetical: `ALL`, `NotPresent`, `Present`) has:

- `pmat[1,1]` = `NotPresent` vs `ALL`
- `pmat[2,1]` = `Present` vs `ALL`
- `pmat[2,2]` = `Present` vs `NotPresent` (the one used for significance in classification)

Stored tables:

```r
.Object@resultados_analisis$stats_gen <- data.frame(
  strain           = cepas,
  median_all       = <per-strain>,
  median_not       = <per-strain>,
  median_present   = <per-strain>,
  p_all_vs_not     = <pmat[1,1] per strain>,
  p_all_vs_pres    = <pmat[2,1] per strain>,
  p_not_vs_pres    = <pmat[2,2] per strain>,
  classification   = <"Cooperator" | "Cheater" | "Neutral" — derived from the lists already stored in summary_gen>
)
.Object@resultados_analisis$stats_gr <- <same shape computed from data_gr>
```

The `classification` column is computed by flipping the existing `summary_gen$positives`/`negatives`/`neutrals` lists into per-strain labels. No change to the function signature, no change to existing stored fields — pure addition.

### 4. `R/analyze-social-behavior.R` — badges below each facet

After each ggplot is built (the NGen and GR boxplots), attach a small `geom_text` layer drawing the classification at `y = -Inf, vjust = 1.8` per strain facet:

- Data source: classification vectors already stored by `summarize_social_behavior()` (must have run first; if missing, skip the annotation — do not error).
- Color palette (explicit to avoid viridis confusion): `Cooperator = "#2e7d32"`, `Cheater = "#c62828"`, `Neutral = "#616161"`.
- Wrap the plot in `ggplot2::coord_cartesian(clip = "off")` and add bottom margin via `theme(plot.margin = margin(5, 5, 25, 5))` so the badge is not clipped.

### 5. `R/analyze-diversity.R` — remove Top-k path + rename axis

Remove:

- Internal helpers `rank_strains()`, `build_best_matrix()`, `plot_best_boxplot()`.
- Computations for `rank_gen`, `rank_gr`, `best_gen`, `best_gr_mat`.
- Four result slots: `diversity_best_gen_table`, `diversity_best_gr_table`, `diversity_best_gen_plot`, `diversity_best_gr_plot` (and their empty-fallback counterparts in the no-monoculture branch).

Rename in `plot_diversity_boxplot()`:

- `ggplot2::labs(x = "Number of strains in consortium", ...)` → `ggplot2::labs(x = "Species richness in consortium", ...)`.

### 6. Release metadata

- `DESCRIPTION`: `Version: 0.2.0`.
- `NAMESPACE`: regenerated by roxygen; should include `export(plot_growth_scatter)`.
- `NEWS.md`: new top-level entry describing the breaking change (removed `diversity_best_*` slots), new `plot_growth_scatter()` function, log10 y-axis on `plot_processed_curves`, per-strain social behavior badges, new `stats_gen` / `stats_gr` tables, axis label rename.
- `man/`: regenerated by `devtools::document()`. New file `plot_growth_scatter.Rd`.

## App changes (`BSocialApp`)

### 1. `R/mod_curvas_raw.R` — no changes

The log10 behavior comes from the package; the app just re-calls `plot_processed_curves()`.

### 2. `R/mod_crecimiento.R` — reactive scatter with outlier checkbox

- Add to UI (next to the existing PDF download button):

  ```r
  checkboxInput(ns("hide_outliers"), "Hide outliers (IQR)", value = FALSE)
  ```

- Replace `plot_to_show <- eventReactive(bsocial_object(), { ... @graficos$growth_scatter })` with:

  ```r
  plot_to_show <- reactive({
    req(bsocial_object())
    bsocialv2::plot_growth_scatter(bsocial_object(), remove_outliers = input$hide_outliers)
  })
  ```

- `renderPlot`, `downloadHandler` unchanged (they already call `plot_to_show()`).

### 3. `R/mod_comportamiento.R` — Statistics sub-tab

- Add a third `nav_panel` after "Growth Rate":

  ```r
  bslib::nav_panel("Statistics",
    tags$div(class = "section-title-row",
      h5("Per-strain statistics (NGen & GR)"),
      downloadButton(ns("download_stats_csv"), "CSV", class = "btn-sm btn-outline-secondary")
    ),
    DT::dataTableOutput(ns("stats_table"))
  )
  ```

- Reactive and render (mirrors the inline project-name pattern already used in this module — `mod_comportamiento.R` does not define a shared `get_proj()` helper):

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
    DT::datatable(stats_combined(), options = list(scrollX = TRUE, pageLength = 20), rownames = FALSE)
  })
  output$download_stats_csv <- downloadHandler(
    filename = function() {
      proj <- bsocial_object()@id_proyecto
      if (is.null(proj) || !nzchar(proj)) proj <- "bsocial"
      paste0(proj, "_social_stats_", Sys.Date(), ".csv")
    },
    content  = function(file) write.csv(stats_combined(), file, row.names = FALSE)
  )
  ```

- The "Statistics" sub-tab is added inside the same `navset_card_tab` that currently wraps "Number of Generations" and "Growth Rate". The existing empty-state / error-state branches at the top of `renderUI` are preserved — if `results$success` is `FALSE`, none of the three sub-tabs render.
- Badges require zero app-side changes (they are inside the ggplot the package returns).

### 4. `R/mod_diversidad.R` — remove Top-k

- Remove the `nav_panel("Best Strains (Top-k)", ...)` block (lines 62-79).
- Remove the "B) Relative fitness using only Top-k strains" section inside the "Data" sub-panel (lines 100-117).
- Drop `plot_best_gen`, `plot_best_gr`, `table_best_gen`, `table_best_gr` fields from the `results()` reactive list.
- Delete the four related outputs (`output$plot_best_gen`, `output$plot_best_gr`, `output$diversity_table_best_gen`, `output$diversity_table_best_gr`) and their four `downloadHandler`s.

### 5. `renv.lock`

- After the package push lands on GitHub main, in the app run `renv::update("bsocialv2")` to pin the new commit SHA (and `Version` should bump to `0.2.0`).
- Commit the updated `renv.lock`.

## Release orchestration

**Phase A — Package** (on `bsocialv2`):

1. Apply package changes in order: `plot-processed-curves` → `analyze-diversity` (removals + rename) → `summarize-social-behavior` (stats tables) → `analyze-social-behavior` (badges) → `plot-growth-scatter` + `analyze-growth` refactor.
2. `devtools::document()` — regenerates `NAMESPACE` and `man/`.
3. `devtools::check()` locally — must pass with 0 errors, 0 warnings.
4. `DESCRIPTION` bump to `0.2.0`.
5. `NEWS.md` entry.
6. Commit + push to `main`.

**Phase B — App** (on `BSocialApp`):

1. `renv::update("bsocialv2")` — pins the new SHA + version in `renv.lock`.
2. Apply app changes: `mod_crecimiento` (checkbox + reactive scatter) → `mod_comportamiento` (Statistics sub-tab) → `mod_diversidad` (Top-k removals).
3. Local smoke test via `pkgload::load_all()` + `run_app()` using the test dataset in `test/`.
4. Commit + push to `main`.
5. Manual redeploy to shinyapps.io via `rsconnect::deployApp()`.

## Risks and mitigations

- **log10 on zeros** — `scale_y_log10` drops non-positive ODs silently; during typical runs the first few preprocessed timepoints may disappear from the plot. Documented in `NEWS.md`.
- **Badge clipping** — `y = -Inf` with the default theme can clip; mitigated by `coord_cartesian(clip = "off")` and increased bottom `plot.margin`. Visual verification required after implementation.
- **Breaking change** — external scripts reading `@resultados_analisis$diversity_best_*` will break. Mitigation: clear `NEWS.md` entry and 0.2.0 bump signaling the break.
- **Scatter reactivity** — moving from a cached ggplot to an on-demand call means the plot rebuilds on every object change. For the sizes of `datos_procesados` seen in practice this is fast; no caching needed.

## Testing plan

- Unit-level (package): run the full pipeline over the test dataset in `tests/` and check:
  - `@resultados_analisis$stats_gen` and `stats_gr` are data.frames with the expected columns and one row per selected strain.
  - `plot_growth_scatter(obj, remove_outliers = TRUE)` produces a ggplot and subtitle reports hidden count matching manual IQR calculation.
  - `@resultados_analisis$diversity_best_*` slots do NOT exist on the output.
  - `plot_processed_curves(obj)$scales` contains a log10 transform.
- Integration (app): load a test project, cycle through Load → Pre-process → Analyze, and verify visually:
  - Raw Curves show log10 y-axis with fine ticks.
  - Growth scatter responds to the checkbox.
  - Social plots have Cooperator/Cheater/Neutral badges at the bottom of each strain facet (both sub-tabs).
  - Social Statistics sub-tab shows a table and CSV download works.
  - Diversity tab has only two sub-tabs (Diversity vs Fitness, Data) and the Data sub-tab has only the top section.
  - Diversity plot x-axis reads "Species richness in consortium".
