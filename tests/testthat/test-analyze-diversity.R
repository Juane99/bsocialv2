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
