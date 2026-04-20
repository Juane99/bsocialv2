test_that("summarize_social_behavior classifies strains", {
  obj <- create_curated_test_object()
  obj <- transform_curated_data(obj)
  obj <- analyze_social_behavior(obj)

  skip_if(!obj@resultados_analisis$social_behavior$success,
          "Social behavior analysis did not succeed with example data")

  obj <- summarize_social_behavior(obj)

  expect_true(!is.null(obj@resultados_analisis$summary_gen))
  expect_true(!is.null(obj@resultados_analisis$summary_gr))

  summary <- obj@resultados_analisis$summary_gen
  expect_true(all(c("positives", "negatives", "neutrals") %in% names(summary)))
})

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
