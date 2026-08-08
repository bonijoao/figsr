test_that("figs classification works on binary outcome", {
  set.seed(123)
  n <- 120
  df <- data.frame(
    x1 = rnorm(n),
    x2 = rnorm(n)
  )
  df$y <- factor(ifelse(df$x1 + df$x2 > 0, "Yes", "No"))
  
  fit <- figs(y ~ x1 + x2, data = df, max_splits = 4, mode = "classification")
  
  expect_s3_class(fit, "figsr_fit")
  expect_equal(fit$mode, "classification")
  
  preds_class <- predict(fit, new_data = df, type = "class")
  expect_true(".pred_class" %in% colnames(preds_class))
  
  preds_prob <- predict(fit, new_data = df, type = "prob")
  expect_true(".pred_No" %in% colnames(preds_prob))
  expect_true(".pred_Yes" %in% colnames(preds_prob))
})
