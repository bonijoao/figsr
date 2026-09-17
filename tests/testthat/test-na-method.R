test_that("na_method is validated and recorded", {
  set.seed(21)
  df <- data.frame(x = rnorm(40))
  df$y <- 2 * (df$x > 0) + rnorm(40, sd = 0.1)

  expect_error(figs(y ~ x, data = df, na_method = "knn"), "should be one of")
  expect_equal(figs(y ~ x, data = df)$na_method, "omit")
  expect_equal(figs(y ~ x, data = df, na_method = "mia")$na_method, "mia")
})

test_that("na_method = 'mia' on complete data reproduces the omit fit", {
  set.seed(22)
  df <- data.frame(x1 = rnorm(80), x2 = rnorm(80),
                   g = factor(sample(c("a", "b", "c"), 80, replace = TRUE)))
  df$y <- 2 * (df$x1 > 0) - (df$g == "c") + rnorm(80, sd = 0.1)

  fit_omit <- figs(y ~ ., data = df, max_splits = 5)
  fit_mia  <- figs(y ~ ., data = df, max_splits = 5, na_method = "mia")

  expect_equal(fit_mia$trees, fit_omit$trees)
  expect_equal(fit_mia$fitted_values, fit_omit$fitted_values)
})

test_that("na.action cannot be combined with na_method = 'mia'", {
  df <- data.frame(x = rnorm(30), y = rnorm(30))
  expect_error(figs(y ~ x, data = df, na_method = "mia", na.action = stats::na.omit),
               "cannot be combined")
})

test_that("a missing outcome is dropped with a warning under mia", {
  set.seed(23)
  df <- data.frame(x = rnorm(40))
  df$y <- 2 * (df$x > 0) + rnorm(40, sd = 0.1)
  df$y[c(3, 7)] <- NA

  expect_warning(fit <- figs(y ~ x, data = df, na_method = "mia"), "2 row")
  expect_equal(length(fit$fitted_values), 38)
})

test_that("a predictor NA that survives na.action is rejected under omit", {
  set.seed(24)
  df <- data.frame(x = rnorm(40))
  df$y <- 2 * (df$x > 0) + rnorm(40, sd = 0.1)
  df$x[5] <- NA

  expect_error(figs(y ~ x, data = df, na.action = stats::na.pass),
               "na_method = \"mia\"")
})

test_that("bagging_figs() forwards na_method to every member", {
  set.seed(25)
  df <- data.frame(x = rnorm(60))
  df$y <- 2 * (df$x > 0) + rnorm(60, sd = 0.1)

  bag <- bagging_figs(y ~ x, data = df, n_estimators = 3, na_method = "mia")
  expect_true(all(vapply(bag$models, function(m) m$na_method == "mia", logical(1))))
})
