test_that("figsr_importance computes feature importance", {
  set.seed(42)
  df <- data.frame(x1 = rnorm(80), x2 = rnorm(80), y = rnorm(80))
  fit <- figs(y ~ x1 + x2, data = df, max_splits = 3)
  
  imp <- figsr_importance(fit)
  expect_s3_class(imp, "tbl_df")
  expect_true(all(c("feature", "gain", "importance") %in% colnames(imp)))
})
