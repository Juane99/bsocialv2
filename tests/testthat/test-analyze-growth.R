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
