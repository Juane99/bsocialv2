`%||%` <- function(a, b) if (is.null(a)) b else a

test_that("plot_growth_scatter returns a ggplot from datos_procesados", {
  obj <- create_curated_test_object()
  obj <- transform_curated_data(obj)

  p <- plot_growth_scatter(obj)
  expect_s3_class(p, "ggplot")
})

test_that("plot_growth_scatter with remove_outliers=TRUE filters high points using IQR", {
  obj <- create_curated_test_object()
  obj <- transform_curated_data(obj)

  # Inject an artificial outlier so the IQR rule has something to catch
  obj@datos_procesados$LogPhase[1] <- max(obj@datos_procesados$LogPhase, na.rm = TRUE) * 10
  obj@datos_procesados$NGen[1]     <- max(obj@datos_procesados$NGen,     na.rm = TRUE) * 10

  p_all  <- plot_growth_scatter(obj, remove_outliers = FALSE)
  p_filt <- plot_growth_scatter(obj, remove_outliers = TRUE)

  expect_lt(nrow(p_filt$data), nrow(p_all$data))
  expect_match(p_filt$labels$subtitle %||% "", "hidden", ignore.case = TRUE)
})
