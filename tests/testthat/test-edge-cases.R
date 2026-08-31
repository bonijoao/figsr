test_that("a fit with no accepted split falls back to the outcome mean", {
  set.seed(11)
  df <- data.frame(x = rnorm(40), y = rnorm(40, mean = 100))

  fit <- figs(y ~ x, data = df, max_splits = 0)

  expect_equal(length(fit$trees), 0)
  expect_equal(fit$intercept, mean(df$y))
  expect_equal(unique(predict(fit, new_data = df)$.pred), mean(df$y))
})

test_that("classification with no accepted split falls back to the base rate", {
  set.seed(12)
  df <- data.frame(x = rnorm(60))
  df$y <- factor(ifelse(df$x > 0, "yes", "no"))

  fit <- figs(y ~ x, data = df, max_splits = 0, mode = "classification")
  probs <- predict(fit, new_data = df, type = "prob")

  expect_equal(unique(probs$.pred_yes), mean(df$y == "yes"))
})

test_that("an intercept is not added once a tree exists", {
  set.seed(13)
  df <- data.frame(x = rnorm(60))
  df$y <- 3 * (df$x > 0) + rnorm(60, sd = 0.1)

  fit <- figs(y ~ x, data = df, max_splits = 3)

  expect_gt(length(fit$trees), 0)
  expect_equal(fit$intercept, 0)
})

test_that("a missing predictor value at prediction time raises a clear error", {
  set.seed(14)
  df <- data.frame(x = rnorm(40))
  df$y <- 2 * (df$x > 0) + rnorm(40, sd = 0.1)
  fit <- figs(y ~ x, data = df, max_splits = 2)

  new_df <- df
  new_df$x[1] <- NA

  expect_error(predict(fit, new_data = new_df), "missing values in the predictor")
})

test_that("a factor level unseen in training is rejected at prediction time", {
  set.seed(15)
  df <- data.frame(g = factor(rep(c("a", "b"), each = 30)))
  df$y <- ifelse(df$g == "a", 0, 5) + rnorm(60, sd = 0.1)
  fit <- figs(y ~ g, data = df, max_splits = 1)

  new_df <- data.frame(g = factor("c", levels = c("a", "b", "c")))

  expect_error(predict(fit, new_data = new_df), "new level")
  expect_equal(nrow(predict(fit, new_data = df)), nrow(df))
})

test_that("bagging records the mode actually fitted, not the one requested", {
  set.seed(16)
  df <- data.frame(x = rnorm(60))
  df$y <- factor(ifelse(df$x > 0, "yes", "no"))

  # `mode` is left at its "regression" default while the outcome is a factor.
  bag <- bagging_figs(y ~ x, data = df, n_estimators = 3)

  expect_equal(bag$mode, "classification")
  expect_named(predict(bag, new_data = df), ".pred_class")
  expect_named(predict(bag, new_data = df, type = "prob"),
               c(".pred_no", ".pred_yes"))
})

test_that("invalid arguments are rejected", {
  df <- data.frame(x = rnorm(30), y = rnorm(30))

  expect_error(figs(y ~ x, data = df, max_splits = -1), "non-negative")
  expect_error(figs(y ~ x, data = df, min_n = 0), "at least 1")
  expect_error(figs(y ~ x, data = df, max_trees = 0), "at least 1")
  expect_error(figs(y ~ x, data = df, mode = "ranking"), "regression")
  expect_error(bagging_figs(y ~ x, data = df, n_estimators = 0), "at least 1")
})

test_that("predictions are unchanged by the index-set traversal", {
  set.seed(17)
  df <- data.frame(
    g = factor(sample(letters[1:4], 200, replace = TRUE)),
    x = rnorm(200)
  )
  df$y <- as.numeric(df$g) + 2 * (df$x > 0.3) + rnorm(200, sd = 0.2)
  fit <- figs(y ~ g + x, data = df, max_splits = 6)

  # Reference implementation: walk one observation at a time.
  by_row <- vapply(seq_len(nrow(df)), function(i) {
    total <- 0
    for (tree in fit$trees) {
      node <- tree[[1]]
      while (!node$is_leaf) {
        value <- df[i, node$feature]
        go_left <- if (node$is_factor) {
          as.character(value) %in% as.character(node$split_val)
        } else {
          value <= node$split_val
        }
        node <- if (go_left) tree[[node$left_child]] else tree[[node$right_child]]
      }
      total <- total + node$value
    }
    total
  }, numeric(1))

  expect_equal(predict(fit, new_data = df)$.pred, by_row)
})
