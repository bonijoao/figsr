test_that("figs_tree() builds a valid parsnip specification", {
  skip_if_not_installed("parsnip")

  spec <- parsnip::set_engine(figs_tree(max_splits = 6, min_n = 5), "figsr")
  spec <- parsnip::set_mode(spec, "regression")

  expect_s3_class(spec, "model_spec")
  expect_equal(spec$engine, "figsr")
  expect_equal(spec$mode, "regression")
})

test_that("the figsr engine is registered for both modes", {
  skip_if_not_installed("parsnip")

  env <- parsnip::get_model_env()
  modes <- env[["figs_tree"]]

  expect_true(all(c("regression", "classification") %in% modes$mode))
  expect_true(all(modes$engine == "figsr"))

  args <- env[["figs_tree_args"]]
  expect_setequal(args$parsnip, c("max_splits", "max_trees", "min_n"))
})

test_that("parsnip fit + predict round-trips for regression", {
  skip_if_not_installed("parsnip")

  set.seed(42)
  n <- 150
  df <- data.frame(x1 = stats::rnorm(n), x2 = stats::rnorm(n))
  df$y <- 3 * (df$x1 > 0) + 2 * (df$x2 > 0.5) + stats::rnorm(n, sd = 0.2)

  spec <- parsnip::set_mode(
    parsnip::set_engine(figs_tree(max_splits = 6, min_n = 5), "figsr"),
    "regression"
  )
  fitted <- parsnip::fit(spec, y ~ x1 + x2, data = df)

  expect_s3_class(fitted, "model_fit")
  expect_s3_class(fitted$fit, "figsr_fit")

  preds <- stats::predict(fitted, new_data = df)
  expect_s3_class(preds, "tbl_df")
  expect_named(preds, ".pred")
  expect_equal(nrow(preds), n)
  expect_gt(stats::cor(df$y, preds$.pred), 0.85)
})

test_that("parsnip fit + predict round-trips for classification", {
  skip_if_not_installed("parsnip")

  set.seed(123)
  n <- 150
  df <- data.frame(x1 = stats::rnorm(n), x2 = stats::rnorm(n))
  df$y <- factor(ifelse(df$x1 + df$x2 > 0, "Yes", "No"))

  spec <- parsnip::set_mode(
    parsnip::set_engine(figs_tree(max_splits = 6, min_n = 5), "figsr"),
    "classification"
  )
  fitted <- parsnip::fit(spec, y ~ x1 + x2, data = df)

  cls <- stats::predict(fitted, new_data = df, type = "class")
  expect_named(cls, ".pred_class")
  expect_s3_class(cls$.pred_class, "factor")
  expect_setequal(levels(cls$.pred_class), c("No", "Yes"))

  prob <- stats::predict(fitted, new_data = df, type = "prob")
  expect_named(prob, c(".pred_No", ".pred_Yes"))
  expect_equal(prob$.pred_No + prob$.pred_Yes, rep(1, n), tolerance = 1e-8)
})

test_that("dials parameters cover the tunable arguments", {
  expect_s3_class(max_splits(), "quant_param")
  expect_s3_class(max_trees(), "quant_param")
  expect_equal(dials::range_get(max_splits(), original = TRUE)$lower, 2L)
})
