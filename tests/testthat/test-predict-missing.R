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
               "missing values in the predictor `x`, which had none")
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
