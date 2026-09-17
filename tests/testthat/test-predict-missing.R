# A one-split tree built directly from make_node(), so routing can be tested
# without the engine.
stump <- function(feature, split_val, is_factor = FALSE,
                  na_dir = NA_character_, split_on_missing = FALSE) {
  list(
    figsr:::make_node(id = 1, is_leaf = FALSE, feature = feature, is_factor = is_factor,
                      split_val = split_val, left_child = 2, right_child = 3, gain = 1,
                      na_dir = na_dir, split_on_missing = split_on_missing),
    figsr:::make_node(id = 2, value = -1),
    figsr:::make_node(id = 3, value = +1)
  )
}

test_that("make_node() carries the missing-value fields by default", {
  nd <- figsr:::make_node(id = 1)
  expect_true(is.na(nd$na_dir))
  expect_false(nd$split_on_missing)
})

test_that("NA follows na_dir on a numeric split", {
  X <- data.frame(x = c(-1, 1, NA))
  expect_equal(figsr:::predict_trees(list(stump("x", 0, na_dir = "left")),  X), c(-1, 1, -1))
  expect_equal(figsr:::predict_trees(list(stump("x", 0, na_dir = "right")), X), c(-1, 1,  1))
})

test_that("NA follows na_dir on a factor split", {
  X <- data.frame(g = factor(c("a", "b", NA), levels = c("a", "b")))
  tr <- stump("g", "a", is_factor = TRUE, na_dir = "right")
  expect_equal(figsr:::predict_trees(list(tr), X), c(-1, 1, 1))
})

test_that("a split on missingness sends NA left and everything else right", {
  X <- data.frame(x = c(NA, 5, -5, NA))
  tr <- stump("x", NA_real_, split_on_missing = TRUE)
  expect_equal(figsr:::predict_trees(list(tr), X), c(-1, 1, 1, -1))
})

test_that("NA on a column with no learned direction is a clear error", {
  X <- data.frame(x = c(-1, NA))
  expect_error(figsr:::predict_trees(list(stump("x", 0)), X),
               "no direction was learned", fixed = TRUE)
})

test_that("the error is accurate when a branch never saw the missing values seen elsewhere in training", {
  # `x` is missing only for rows where `z <= 0`; the tree first splits on `z`
  # and only then, inside the `z > 0` branch (where `x` is always observed),
  # splits on `x`. That `x`-split node never saw a missing value during
  # training, even though `x` did have missing values elsewhere in the
  # training data and the model was fitted with na_method = "mia". Predicting
  # a new row that reaches that branch with `x` missing must still raise a
  # clear error, and the error must not claim `x` "had none" missing at fit
  # time, since that would be false.
  nL <- 100
  nRh <- 50
  z <- c(rep(-1, nL), rep(1, 2 * nRh))
  x <- c(rep(NA_real_, nL), rep(0, nRh), rep(5, nRh))
  y <- c(rep(100, nL), rep(0, nRh), rep(5, nRh))
  df <- data.frame(z = z, x = x, y = y)

  fit <- figs(y ~ z + x, data = df, max_splits = 2, na_method = "mia")

  # Confirm the expected tree shape: root splits on z, and the z > 0 branch
  # splits on x.
  expect_equal(fit$trees[[1]][[1]]$feature, "z")
  expect_equal(fit$trees[[1]][[3]]$feature, "x")
  expect_true(is.na(fit$trees[[1]][[3]]$na_dir))

  new_data <- data.frame(z = 1, x = NA_real_)
  expect_error(predict(fit, new_data = new_data), "no direction was learned",
               fixed = TRUE)
  err <- tryCatch(predict(fit, new_data = new_data), error = function(e) e)
  expect_false(grepl("which had none when the model was fitted",
                      conditionMessage(err), fixed = TRUE))
})

test_that("nodes from a pre-0.2.0 fit (no na fields) still route complete data", {
  old_node <- figsr:::make_node(id = 1, is_leaf = FALSE, feature = "x", split_val = 0,
                                left_child = 2, right_child = 3, gain = 1)
  old_node$na_dir <- NULL
  old_node$split_on_missing <- NULL
  tr <- list(old_node, figsr:::make_node(id = 2, value = -1), figsr:::make_node(id = 3, value = 1))
  expect_equal(figsr:::predict_trees(list(tr), data.frame(x = c(-2, 2))), c(-1, 1))
  expect_error(figsr:::predict_trees(list(tr), data.frame(x = NA_real_)), "missing values")
})
