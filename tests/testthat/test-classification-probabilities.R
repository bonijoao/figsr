## Probability scale of binary classification predictions.
##
## The engine encodes the outcome as 0/1 and fits squared-error on the running
## residuals, so the sum of leaf values already estimates P(y = second level).
## Predictions must therefore be read on the probability scale directly.

sep_data <- function(n = 300, seed = 11) {
  set.seed(seed)
  df <- data.frame(x1 = stats::rnorm(n), x2 = stats::rnorm(n))
  # imbalanced and separable: about 16% "Yes"
  df$y <- factor(ifelse(df$x1 > 1, "Yes", "No"), levels = c("No", "Yes"))
  df
}

test_that("predicted probabilities reach both ends of the unit interval", {
  df <- sep_data()
  fit <- figs(y ~ x1 + x2, data = df, max_splits = 4, mode = "classification")

  prob <- predict(fit, new_data = df, type = "prob")$.pred_Yes

  expect_gte(min(prob), 0)
  expect_lte(max(prob), 1)
  expect_lt(min(prob), 0.05)
  expect_gt(max(prob), 0.95)
})

test_that("mean predicted probability matches the outcome rate", {
  df <- sep_data()
  fit <- figs(y ~ x1 + x2, data = df, max_splits = 4, mode = "classification")

  prob <- predict(fit, new_data = df, type = "prob")$.pred_Yes

  expect_equal(mean(prob), mean(df$y == "Yes"), tolerance = 0.05)
})

test_that("predicted class recovers a separable imbalanced outcome", {
  df <- sep_data()
  fit <- figs(y ~ x1 + x2, data = df, max_splits = 4, mode = "classification")

  cls <- predict(fit, new_data = df, type = "class")$.pred_class

  expect_gt(mean(cls == df$y), 0.9)
})

test_that("bagging returns probabilities for classification", {
  df <- sep_data(n = 200, seed = 12)
  bag <- bagging_figs(y ~ x1 + x2, data = df, n_estimators = 5,
                      max_splits = 4, mode = "classification")

  prob <- predict(bag, new_data = df, type = "prob")

  expect_true(all(c(".pred_No", ".pred_Yes") %in% colnames(prob)))
  expect_gte(min(prob$.pred_Yes), 0)
  expect_lte(max(prob$.pred_Yes), 1)
  expect_equal(prob$.pred_No + prob$.pred_Yes, rep(1, nrow(df)), tolerance = 1e-8)
})

test_that("bagging predicted class recovers a separable imbalanced outcome", {
  df <- sep_data(n = 200, seed = 12)
  bag <- bagging_figs(y ~ x1 + x2, data = df, n_estimators = 5,
                      max_splits = 4, mode = "classification")

  cls <- predict(bag, new_data = df)$.pred_class

  expect_gt(mean(cls == df$y), 0.9)
})
