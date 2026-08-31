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
