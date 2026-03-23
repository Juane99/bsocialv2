test_that("analyze_diversity creates diversity plots and tables", {
  obj <- create_curated_test_object()
  obj <- transform_curated_data(obj)
  obj <- analyze_social_behavior(obj)
  obj <- analyze_diversity(obj)

  expect_true(!is.null(obj@graficos$diversity_gen_plot))
  expect_s3_class(obj@graficos$diversity_gen_plot, "ggplot")
  expect_true(!is.null(obj@resultados_analisis$diversity_gen_table))
})
