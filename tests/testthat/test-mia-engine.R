# Helper: does any split node in the fit satisfy `pred`?
any_node <- function(fit, pred) {
  any(vapply(unlist(fit$trees, recursive = FALSE),
             function(nd) !isTRUE(nd$is_leaf) && isTRUE(pred(nd)), logical(1)))
}

test_that("no row is dropped under mia", {
  set.seed(41)
  df <- data.frame(x1 = rnorm(100), x2 = rnorm(100))
  df$y <- 2 * (df$x1 > 0) + rnorm(100, sd = 0.1)
  df$x2[1:30] <- NA

  fit <- figs(y ~ ., data = df, max_splits = 4, na_method = "mia")
  expect_equal(length(fit$fitted_values), 100)
  expect_equal(nrow(predict(fit, new_data = df)), 100)
})

test_that("informative missingness is learned as a direction (splits A/B)", {
  set.seed(42)
  n <- 300
  df <- data.frame(x = rnorm(n))
  df$y <- 3 * (df$x > 0) + rnorm(n, sd = 0.2)
  # Only high-x rows go missing: the right direction is "right".
  hi <- which(df$x > 0)
  df$x[sample(hi, 60)] <- NA

  fit <- figs(y ~ x, data = df, max_splits = 1, na_method = "mia")
  root <- fit$trees[[1]][[1]]
  expect_false(root$split_on_missing)
  expect_equal(root$na_dir, "right")

  fit_omit <- figs(y ~ x, data = df, max_splits = 1)
  rmse <- function(f) sqrt(mean((df$y - predict(f, new_data = df)$.pred)^2, na.rm = TRUE))
  # omit cannot even predict the NA rows; compare on the rows it can
  pred_omit <- tryCatch(predict(fit_omit, new_data = df)$.pred, error = function(e) NULL)
  expect_null(pred_omit)
  expect_lt(rmse(fit), 0.5)
})

test_that("missingness itself is chosen when it is the strongest signal (split C)", {
  set.seed(43)
  n <- 200
  df <- data.frame(x = rnorm(n), z = rnorm(n))
  df$x[sample.int(n, 80)] <- NA
  df$y <- 5 * is.na(df$x) + rnorm(n, sd = 0.2)

  fit <- figs(y ~ x + z, data = df, max_splits = 1, na_method = "mia")
  root <- fit$trees[[1]][[1]]
  expect_true(root$split_on_missing)
  expect_equal(root$feature, "x")
  expect_equal(unname(round(predict(fit, new_data = df)$.pred[is.na(df$x)][1])), 5)
})

test_that("a factor with missing values is split, and NA is not a level", {
  set.seed(44)
  n <- 200
  df <- data.frame(g = factor(sample(c("a", "b", "c"), n, replace = TRUE)))
  df$y <- ifelse(df$g == "c", 4, 0) + rnorm(n, sd = 0.2)
  df$g[sample.int(n, 40)] <- NA

  fit <- figs(y ~ g, data = df, max_splits = 1, na_method = "mia")
  root <- fit$trees[[1]][[1]]
  expect_true(root$is_factor)
  expect_false("NA" %in% root$split_val)
  expect_true(root$na_dir %in% c("left", "right"))
})

test_that("a 10-level factor with missing values is still eligible (D-F2)", {
  set.seed(45)
  n <- 400
  df <- data.frame(g = factor(sample(letters[1:10], n, replace = TRUE)))
  df$y <- ifelse(df$g %in% c("a", "b"), 3, 0) + rnorm(n, sd = 0.2)
  df$g[sample.int(n, 40)] <- NA

  fit <- figs(y ~ g, data = df, max_splits = 1, na_method = "mia")
  expect_equal(length(fit$trees), 1)
  expect_equal(fit$trees[[1]][[1]]$feature, "g")
})

test_that("missing values under MCAR do not hurt appreciably", {
  set.seed(46)
  n <- 400
  df <- data.frame(x1 = rnorm(n), x2 = rnorm(n))
  df$y <- 2 * (df$x1 > 0) + 2 * (df$x2 > 0) + rnorm(n, sd = 0.2)
  full <- figs(y ~ ., data = df, max_splits = 4)
  df_na <- df
  df_na$x1[sample.int(n, 40)] <- NA
  df_na$x2[sample.int(n, 40)] <- NA
  mia <- figs(y ~ ., data = df_na, max_splits = 4, na_method = "mia")

  rmse <- function(f, d) sqrt(mean((d$y - predict(f, new_data = d)$.pred)^2))
  expect_lt(rmse(mia, df_na), rmse(full, df) + 0.5)
})

test_that("the split search ignores NA when na_method is omit and data are complete", {
  set.seed(47)
  df <- data.frame(x = rnorm(60))
  df$y <- 2 * (df$x > 0) + rnorm(60, sd = 0.1)
  a <- figsr:::find_best_split(df["x"], df$y, seq_len(60), min_n = 5, na_method = "omit")
  b <- figsr:::find_best_split(df["x"], df$y, seq_len(60), min_n = 5, na_method = "mia")
  expect_equal(a, b)
  expect_true(is.na(a$na_dir))
  expect_false(a$split_on_missing)
})
