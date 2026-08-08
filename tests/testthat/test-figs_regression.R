test_that("figs regression works on additive data", {
  set.seed(42)
  n <- 150
  df <- data.frame(
    x1 = rnorm(n),
    x2 = rnorm(n),
    x3 = rnorm(n)
  )
  df$y <- 3 * (df$x1 > 0) + 2 * (df$x2 > 0.5) + rnorm(n, sd = 0.2)
  
  fit <- figs(y ~ x1 + x2 + x3, data = df, max_splits = 4, min_n = 5)
  
  expect_s3_class(fit, "figsr_fit")
  expect_equal(fit$mode, "regression")
  expect_true(length(fit$trees) >= 1)
  
  preds <- predict(fit, new_data = df)
  expect_s3_class(preds, "tbl_df")
  expect_true(".pred" %in% colnames(preds))
  expect_equal(nrow(preds), n)
  
  # Correlation should be strong
  r <- cor(df$y, preds$.pred)
  expect_gt(r, 0.85)
})
