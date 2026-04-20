test_that("plot_processed_curves uses a log10 y-axis", {
  obj <- create_raw_test_object()
  obj <- transform_raw_data(obj, groups = NULL, bg_type = "threshold", bg_param = 0.1)
  p <- plot_processed_curves(obj)

  expect_s3_class(p, "ggplot")

  y_scale <- p$scales$scales[[which(vapply(
    p$scales$scales, function(s) "y" %in% s$aesthetics, logical(1)
  ))]]
  expect_equal(y_scale$trans$name, "log-10")
  expect_match(p$labels$y, "log10", ignore.case = TRUE)
})
