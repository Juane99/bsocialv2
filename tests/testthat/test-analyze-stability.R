test_that("analyze_stability creates violin plots with statistics", {
  obj <- create_curated_test_object()
  obj <- transform_curated_data(obj)
  obj <- analyze_stability(obj)

  expect_true(!is.null(obj@graficos$stability_ngen_plot))
  expect_s3_class(obj@graficos$stability_ngen_plot, "ggplot")
  expect_true(!is.null(obj@resultados_analisis$stability_cv_data))
})
