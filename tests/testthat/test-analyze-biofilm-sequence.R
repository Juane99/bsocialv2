test_that("analyze_biofilm_sequence creates graph paths", {
  obj <- create_curated_test_object()
  obj <- transform_curated_data(obj)
  obj <- analyze_social_behavior(obj)
  obj <- analyze_biofilm_sequence(obj)

  expect_true(!is.null(obj@resultados_analisis$biofilm_gen_paths))
  expect_true(is.function(obj@graficos$biofilm_gen_plot_func))
})
