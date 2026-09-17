test_that("print() reports which predictors carry a split", {
  set.seed(31)
  df <- data.frame(x1 = rnorm(60), x2 = rnorm(60))
  df$y <- 2 * (df$x1 > 0) + rnorm(60, sd = 0.2)
  fit <- figs(y ~ x1 + x2, data = df, max_splits = 2)

  out <- utils::capture.output(print(fit))
  expect_true(any(grepl("Predictors        : x1, x2", out, fixed = TRUE)))
  expect_true(any(grepl("Used in Splits    : x1", out, fixed = TRUE)))

  empty <- figs(y ~ x1 + x2, data = df, max_splits = 0)
  expect_true(any(grepl("Used in Splits    : none",
                        utils::capture.output(print(empty)), fixed = TRUE)))
})

test_that("summary() prints factor rules and flags the probability scale", {
  set.seed(32)
  df <- data.frame(g = factor(sample(c("a", "b", "c"), 90, replace = TRUE)))
  df$y <- as.numeric(df$g) + rnorm(90, sd = 0.1)
  out <- utils::capture.output(summary(figs(y ~ g, data = df, max_splits = 2)))
  expect_true(any(grepl("IN (", out, fixed = TRUE)))

  dfc <- data.frame(x = rnorm(80))
  dfc$y <- factor(ifelse(dfc$x > 0, "yes", "no"))
  out_c <- utils::capture.output(summary(figs(y ~ x, data = dfc, max_splits = 2)))
  expect_true(any(grepl('contributions to P(y = "yes")', out_c, fixed = TRUE)))

  empty <- utils::capture.output(summary(figs(y ~ x, data = dfc, max_splits = 0)))
  expect_true(any(grepl("No splits performed", empty, fixed = TRUE)))
})

test_that("print() and summary() return their object invisibly", {
  set.seed(33)
  df <- data.frame(x = rnorm(40), y = rnorm(40))
  fit <- figs(y ~ x, data = df, max_splits = 2)

  utils::capture.output({
    printed <- withVisible(print(fit))
    summarised <- withVisible(summary(fit))
  })

  expect_false(printed$visible)
  expect_false(summarised$visible)
  expect_identical(printed$value, fit)
  expect_identical(summarised$value, fit)
})

test_that("plot() renders every style and validates its arguments", {
  set.seed(34)
  df <- data.frame(x1 = rnorm(80), x2 = rnorm(80))
  df$y <- 2 * (df$x1 > 0) + 1.5 * (df$x2 > 0.5) + rnorm(80, sd = 0.2)
  fit <- figs(y ~ x1 + x2, data = df, max_splits = 5)

  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)

  for (style in c("scientific", "modern", "classic")) {
    expect_silent(plot(fit, style = style))
  }
  expect_error(plot(fit, style = "scientfic"), "should be one of")
  expect_error(plot(fit, tree_idx = NA), "Invalid `tree_idx`")
  expect_error(plot(fit, tree_idx = 99), "Invalid `tree_idx`")
  expect_message(plot(figs(y ~ x1, data = df, max_splits = 0)), "no trees")
})

test_that("plot() restores the graphical parameters it changed", {
  set.seed(35)
  df <- data.frame(x = rnorm(60))
  df$y <- 2 * (df$x > 0) + rnorm(60, sd = 0.2)
  fit <- figs(y ~ x, data = df, max_splits = 2)

  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::par(mfrow = c(2, 2))
  before <- graphics::par("mfrow")
  plot(fit)
  expect_equal(graphics::par("mfrow"), before)
})

test_that("plot() restores the outer margin reserved for main", {
  set.seed(39)
  df <- data.frame(x = rnorm(60))
  df$y <- 2 * (df$x > 0) + rnorm(60, sd = 0.2)
  fit <- figs(y ~ x, data = df, max_splits = 2)

  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::par(mfrow = c(2, 2), oma = c(1, 1, 1, 1))
  before_mfrow <- graphics::par("mfrow")
  before_oma   <- graphics::par("oma")
  plot(fit, main = "Title")
  expect_equal(graphics::par("mfrow"), before_mfrow)
  expect_equal(graphics::par("oma"), before_oma)
})

test_that("plot() accepts main and tree_names, and validates their length", {
  set.seed(37)
  df <- data.frame(x1 = rnorm(80), x2 = rnorm(80))
  df$y <- 2 * (df$x1 > 0) - 1.5 * (df$x2 > 0) + rnorm(80, sd = 0.2)
  fit <- figs(y ~ x1 + x2, data = df, max_splits = 5)
  n_tree <- length(fit$trees)

  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)

  expect_silent(plot(fit, main = "FIGS tree sum"))
  expect_silent(plot(fit, tree_names = "same name for every tree"))
  expect_silent(plot(fit, tree_names = c("first tree", rep(NA_character_, n_tree - 1))))
  expect_silent(plot(fit, tree_idx = 1,
                     tree_names = c("first tree", rep(NA_character_, n_tree - 1))))

  expect_error(plot(fit, main = c("a", "b")), "`main` must be a single string")
  expect_error(plot(fit, main = NA_character_), "`main` must be a single string")
  expect_error(plot(fit, tree_names = rep("x", n_tree + 1)), paste0("length ", n_tree))
})

test_that("plot() renders leaves of both signs without error, in every style", {
  set.seed(38)
  df <- data.frame(x = rnorm(80))
  df$y <- 3 * (df$x > 0) - 3 * (df$x <= 0) + rnorm(80, sd = 0.1)
  fit <- figs(y ~ x, data = df, max_splits = 1)

  leaf_vals <- vapply(fit$trees[[1]], function(nd) {
    if (isTRUE(nd$is_leaf)) nd$value else NA_real_
  }, numeric(1))
  leaf_vals <- leaf_vals[!is.na(leaf_vals)]
  expect_true(any(leaf_vals > 0))
  expect_true(any(leaf_vals < 0))

  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  for (style in c("scientific", "modern", "classic")) {
    expect_silent(plot(fit, style = style))
  }
})

test_that("figsr_importance() handles absolute scaling and unused predictors", {
  set.seed(36)
  df <- data.frame(x1 = rnorm(80), x2 = rnorm(80))
  df$y <- 3 * (df$x1 > 0) + rnorm(80, sd = 0.2)
  fit <- figs(y ~ x1 + x2, data = df, max_splits = 3)

  abs_imp <- figsr_importance(fit, relative = FALSE)
  expect_true(all(abs_imp$importance >= 0))
  expect_setequal(abs_imp$feature, c("x1", "x2"))
  expect_error(figsr_importance(df), "figsr_fit")
})
