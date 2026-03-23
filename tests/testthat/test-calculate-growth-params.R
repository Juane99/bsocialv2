test_that("calculate_growth_params extracts NGen and GR", {
  skip_on_cran()

  obj <- create_raw_test_object()
  obj <- transform_raw_data(obj, groups = NULL, bg_type = "threshold", bg_param = 0.1)
  obj <- calculate_growth_params(obj, method = "growthcurver")

  expect_true(nrow(obj@datos_procesados) > 0)
  expect_true(all(c("NGen", "GR") %in% colnames(obj@datos_procesados)))
  expect_true(any(obj@datos_procesados$NGen > 0, na.rm = TRUE))
})
