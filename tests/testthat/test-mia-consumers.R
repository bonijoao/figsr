split_c_fit <- function() {
  set.seed(61)
  n <- 200
  df <- data.frame(x = rnorm(n), z = rnorm(n))
  df$x[sample.int(n, 80)] <- NA
  df$y <- 5 * is.na(df$x) + 2 * (df$z > 0) + rnorm(n, sd = 0.2)
  list(df = df, fit = figs(y ~ x + z, data = df, max_splits = 2, na_method = "mia"))
}

direction_fit <- function() {
  set.seed(62)
  n <- 300
  df <- data.frame(x = rnorm(n))
  df$y <- 3 * (df$x > 0) + rnorm(n, sd = 0.2)
  df$x[sample(which(df$x > 0), 60)] <- NA
  list(df = df, fit = figs(y ~ x, data = df, max_splits = 1, na_method = "mia"))
}

test_that("importance reports a split on missingness on its own row", {
  imp <- figsr_importance(split_c_fit()$fit, relative = FALSE)
  expect_true("missing(x)" %in% imp$feature)
  expect_true(all(c("x", "z") %in% imp$feature))
  expect_gt(imp$gain[imp$feature == "missing(x)"], 0)
})

test_that("importance credits a learned direction to the variable itself", {
  imp <- figsr_importance(direction_fit()$fit, relative = FALSE)
  expect_false(any(grepl("missing", imp$feature)))
  expect_gt(imp$gain[imp$feature == "x"], 0)
})

test_that("summary() prints IS MISSING rules in ASCII", {
  out_c <- paste(capture.output(summary(split_c_fit()$fit)), collapse = "\n")
  expect_match(out_c, "IF x IS MISSING")
  expect_match(out_c, "IF x IS NOT MISSING")

  out_d <- paste(capture.output(summary(direction_fit()$fit)), collapse = "\n")
  expect_match(out_d, "OR x IS MISSING")

  expect_true(all(utf8ToInt(out_c) < 128))
  expect_true(all(utf8ToInt(out_d) < 128))
})

test_that("print() reports the missing-value method", {
  out <- paste(capture.output(print(direction_fit()$fit)), collapse = "\n")
  expect_match(out, "Missing values    : mia")
  set.seed(63)
  df <- data.frame(x = rnorm(30)); df$y <- df$x + rnorm(30, sd = .1)
  out_omit <- paste(capture.output(print(figs(y ~ x, data = df))), collapse = "\n")
  expect_match(out_omit, "Missing values    : omit")
})

test_that("plot() renders nodes with missing-value routing in every style", {
  fit_c <- split_c_fit()$fit
  fit_d <- direction_fit()$fit
  tmp <- tempfile(fileext = ".png")
  grDevices::png(tmp)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)
  for (st in c("scientific", "modern", "classic")) {
    expect_silent(plot(fit_c, style = st))
    expect_silent(plot(fit_d, style = st))
  }
})
