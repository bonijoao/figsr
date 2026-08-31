## Leaf values must be absolute contributions of their tree.
##
## `predict_trees()` sums one leaf value per tree, so a leaf created by
## splitting an already-valued leaf must carry the full contribution for the
## observations reaching it, not the increment over its parent.

step_data <- function(n = 400, seed = 4) {
  set.seed(seed)
  df <- data.frame(x1 = stats::runif(n, -2, 2))
  df$y <- ifelse(df$x1 <= 0, 0, ifelse(df$x1 <= 1, 1, 5))
  df
}

test_that("predictions span the range of a three-level step target", {
  df <- step_data()

  fit <- figs(y ~ x1, data = df, max_splits = 2)
  pred <- predict(fit, new_data = df)$.pred

  expect_gt(max(pred), 4.5)
  expect_lt(min(pred), 0.5)
})

test_that("a three-level step target is fitted with high explained variance", {
  df <- step_data()

  fit <- figs(y ~ x1, data = df, max_splits = 2)
  pred <- predict(fit, new_data = df)$.pred
  r2 <- 1 - sum((df$y - pred)^2) / sum((df$y - mean(df$y))^2)

  expect_gt(r2, 0.95)
})

test_that("fitted values keep the mean of the outcome", {
  df <- step_data()

  fit <- figs(y ~ x1, data = df, max_splits = 2)

  expect_equal(mean(fit$fitted_values), mean(df$y), tolerance = 1e-6)
})
