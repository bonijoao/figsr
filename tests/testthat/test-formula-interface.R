test_that("transformed terms survive a round trip through predict()", {
  set.seed(21)
  df <- data.frame(x = runif(80, 1, 10))
  df$y <- 2 * log(df$x) + rnorm(80, sd = 0.1)

  fit <- figs(y ~ log(x), data = df, max_splits = 3)
  preds <- predict(fit, new_data = df)

  expect_equal(fit$feature_names, "log(x)")
  expect_equal(nrow(preds), nrow(df))
  expect_gt(stats::cor(preds$.pred, df$y), 0.9)
})

test_that("matrix-valued terms are rejected instead of producing NA gains", {
  set.seed(22)
  df <- data.frame(x = rnorm(60), y = rnorm(60))

  expect_error(figs(y ~ poly(x, 2), data = df), "Matrix-valued terms")
})

test_that("`subset` and `na.action` reach the model frame", {
  set.seed(23)
  df <- data.frame(x = rnorm(80), y = rnorm(80))

  fit <- figs(y ~ x, data = df, subset = 1:20, max_splits = 2)
  expect_equal(length(fit$fitted_values), 20)

  df_na <- df
  df_na$x[1] <- NA
  expect_equal(length(figs(y ~ x, data = df_na, max_splits = 2)$fitted_values), 79)
  expect_error(figs(y ~ x, data = df_na, na.action = stats::na.fail))
})

test_that("case weights are refused rather than silently ignored", {
  df <- data.frame(x = rnorm(40), y = rnorm(40))
  expect_error(figs(y ~ x, data = df, weights = rep(1, 40)), "Case weights")
})

test_that("large integer predictors do not overflow the midpoint search", {
  set.seed(24)
  df <- data.frame(id = c(rep(2100000000L, 20), rep(2147480000L, 20)))
  df$y <- c(rnorm(20), rnorm(20, mean = 5))

  fit <- figs(y ~ id, data = df, max_splits = 1)
  expect_equal(fit$total_splits, 1)
})

test_that("factor eligibility follows the levels present, not those declared", {
  set.seed(25)
  df <- data.frame(
    g = factor(sample(c("a", "b", "c"), 90, replace = TRUE), levels = letters[1:12])
  )
  df$y <- as.numeric(df$g) + rnorm(90, sd = 0.1)

  fit <- figs(y ~ g, data = df, max_splits = 2)
  expect_gt(fit$total_splits, 0)
})

test_that("a predictor named .outcome survives the x/y interface", {
  set.seed(26)
  x <- data.frame(.outcome = rnorm(60), x2 = rnorm(60))
  y <- 3 * x$.outcome + rnorm(60, sd = 0.1)

  fit <- fit_figs(x = x, y = y, max_splits = 3)

  expect_true(".outcome" %in% fit$feature_names)
  expect_gt(stats::cor(fit$fitted_values, y), 0.9)
})

test_that("fit_figs() accepts the formula interface and rejects neither", {
  set.seed(27)
  df <- data.frame(x = rnorm(40))
  df$y <- 2 * (df$x > 0) + rnorm(40, sd = 0.2)

  expect_s3_class(fit_figs(formula = y ~ x, data = df, max_splits = 2), "figsr_fit")
  expect_error(fit_figs(), "Invalid input")
})

test_that("an unsupported prediction type is an error", {
  set.seed(28)
  df <- data.frame(x = rnorm(40), y = rnorm(40))
  fit <- figs(y ~ x, data = df, max_splits = 2)

  expect_error(predict(fit, new_data = df, type = "prob"), "must be one of")
  expect_error(predict(fit), "must be provided")
  expect_error(predict_figs(fit, new_data = data.frame(z = 1)), "missing in")
})

test_that("bagging survives a character outcome and predicts in regression mode", {
  set.seed(29)
  df <- data.frame(x = rnorm(40))
  df$y <- ifelse(seq_len(40) <= 3, "rare", "common")

  bag <- bagging_figs(y ~ x, data = df, n_estimators = 20)
  expect_equal(bag$mode, "classification")

  num <- data.frame(x = rnorm(60))
  num$y <- 2 * (num$x > 0) + rnorm(60, sd = 0.2)
  bag_num <- bagging_figs(y ~ x, data = num, n_estimators = 3)
  expect_named(predict(bag_num, new_data = num), ".pred")
})
