test_that("transform_raw_data processes plate data with threshold correction", {
  obj <- create_raw_test_object()
  obj <- transform_raw_data(obj, groups = NULL, bg_type = "threshold", bg_param = 0.1)

  expect_true(!is.null(obj@resultados_analisis$final_curves))
  expect_true(!is.null(obj@resultados_analisis$cycles))
  expect_true(nrow(obj@resultados_analisis$final_curves) > 0)
})

test_that("transform_raw_data fails without plates", {
  obj <- new("bsocial")
  obj@datos_crudos <- list(type = "raw", plates = list())
  expect_error(transform_raw_data(obj, groups = NULL, bg_type = "threshold", bg_param = 0.1))
})
