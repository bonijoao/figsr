make_na_data <- function(n = 120, seed = 51) {
  set.seed(seed)
  df <- data.frame(x1 = stats::rnorm(n), x2 = stats::rnorm(n))
  df$y <- 2 * (df$x1 > 0) + 1.5 * (df$x2 > 0) + stats::rnorm(n, sd = 0.2)
  df$x2[seq_len(n / 4)] <- NA
  df
}

test_that("figs() keeps every row under mia", {
  df <- make_na_data()
  fit <- figs(y ~ ., data = df, max_splits = 4, na_method = "mia")
  expect_equal(length(fit$fitted_values), nrow(df))
})

test_that("parsnip::fit() with a formula keeps every row under mia", {
  skip_if_not_installed("parsnip")
  df <- make_na_data()
  spec <- parsnip::set_mode(
    parsnip::set_engine(figs_tree(max_splits = 4), "figsr", na_method = "mia"), "regression")
  fitted <- parsnip::fit(spec, y ~ ., data = df)
  expect_equal(length(fitted$fit$fitted_values), nrow(df))
  expect_equal(nrow(stats::predict(fitted, new_data = df)), nrow(df))
})

test_that("parsnip::fit_xy() keeps every row under mia", {
  skip_if_not_installed("parsnip")
  df <- make_na_data()
  spec <- parsnip::set_mode(
    parsnip::set_engine(figs_tree(max_splits = 4), "figsr", na_method = "mia"), "regression")
  fitted <- parsnip::fit_xy(spec, x = df[, c("x1", "x2")], y = df$y)
  expect_equal(length(fitted$fit$fitted_values), nrow(df))
})

test_that("a workflow with add_formula() keeps every row under mia", {
  skip_if_not_installed("parsnip")
  skip_if_not_installed("workflows")
  df <- make_na_data()
  spec <- parsnip::set_mode(
    parsnip::set_engine(figs_tree(max_splits = 4), "figsr", na_method = "mia"), "regression")
  wf <- workflows::add_model(workflows::add_formula(workflows::workflow(), y ~ .), spec)
  wf_fit <- parsnip::fit(wf, data = df)
  expect_equal(length(workflows::extract_fit_engine(wf_fit)$fitted_values), nrow(df))
  expect_equal(nrow(stats::predict(wf_fit, new_data = df)), nrow(df))
})

test_that("a workflow with add_recipe() keeps every row under mia", {
  skip_if_not_installed("parsnip")
  skip_if_not_installed("workflows")
  skip_if_not_installed("recipes")
  df <- make_na_data()
  spec <- parsnip::set_mode(
    parsnip::set_engine(figs_tree(max_splits = 4), "figsr", na_method = "mia"), "regression")
  rec <- recipes::recipe(y ~ ., data = df)
  wf <- workflows::add_model(workflows::add_recipe(workflows::workflow(), rec), spec)
  wf_fit <- parsnip::fit(wf, data = df)
  expect_equal(length(workflows::extract_fit_engine(wf_fit)$fitted_values), nrow(df))
})

test_that("bagging_figs() fits and predicts with missing values under mia", {
  df <- make_na_data()
  bag <- bagging_figs(y ~ ., data = df, n_estimators = 3, max_splits = 4, na_method = "mia")
  expect_equal(nrow(predict(bag, new_data = df)), nrow(df))
})

test_that("classification works with missing predictors under mia", {
  df <- make_na_data()
  df$y <- factor(ifelse(df$y > 1.5, "hi", "lo"))
  fit <- figs(y ~ ., data = df, max_splits = 4, na_method = "mia")
  pr <- predict(fit, new_data = df, type = "prob")
  expect_equal(nrow(pr), nrow(df))
  expect_true(all(pr$.pred_hi >= 0 & pr$.pred_hi <= 1))
})
