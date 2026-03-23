test_that("transform_curated_data populates datos_procesados", {
  obj <- create_curated_test_object()
  obj <- transform_curated_data(obj)

  expect_true(nrow(obj@datos_procesados) > 0)
  expect_true(all(c("Consortia", "NGen", "GR", "LogPhase") %in% colnames(obj@datos_procesados)))
})

test_that("transform_curated_data preserves strain columns", {
  obj <- create_curated_test_object()
  obj <- transform_curated_data(obj)

  strains <- obj@cepas_seleccionadas
  # At least some strain columns should be present
  expect_true(any(strains %in% colnames(obj@datos_procesados)))
})

test_that("transform_curated_data fails without curated data", {
  obj <- new("bsocial")
  obj@datos_crudos <- list(type = "curated")
  expect_error(transform_curated_data(obj))
})
