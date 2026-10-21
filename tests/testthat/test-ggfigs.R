types <- c("tree", "rules", "waterfall", "cuts", "profile")

# Draw the plot for real, into a temporary file, which is where most drawing
# errors surface.
expect_renders <- function(p) {
  expect_s3_class(p, "ggplot")
  file <- tempfile(fileext = ".pdf")
  on.exit(unlink(file))
  expect_no_error(ggplot2::ggsave(file, p, width = 9, height = 6))
}

geom_classes <- function(p) {
  unlist(lapply(p$layers, function(l) class(l$geom)))
}

fits <- local({
  pima <- pima_diabetes
  ir <- iris[iris$Species != "setosa", ]
  ir$Species <- droplevels(ir$Species)
  ir$size <- cut(ir$Petal.Width, 3, labels = c("small", "mid", "large"))
  list(
    regression = list(
      fit = figs(mpg ~ wt + hp + disp + qsec, data = mtcars, max_splits = 6),
      data = mtcars),
    mia = list(
      fit = figs(Outcome ~ ., data = pima, max_splits = 6, max_trees = 3,
                 min_n = 20, na_method = "mia"),
      data = pima),
    factor_predictor = list(
      fit = figs(Species ~ Sepal.Length + Sepal.Width + size, data = ir,
                 max_splits = 8),
      data = ir),
    formula_outcome = list(
      fit = figs(factor(am) ~ wt + hp + qsec, data = mtcars, max_splits = 5),
      data = mtcars)
  )
})

test_that("every view renders as a static ggplot, in both modes of the model", {
  for (case in names(fits)) {
    fit <- fits[[case]]$fit
    d <- fits[[case]]$data
    for (type in types) {
      p <- ggfigs(fit, type, data = d, newdata = d[1, , drop = FALSE])
      expect_renders(p)
      # the static plot must not need 'ggiraph'
      expect_false(any(grepl("Interactive", geom_classes(p))),
                   label = paste(case, type, "uses no interactive geom"))
    }
  }
})

test_that("every view saves to PDF through the default pdf() device", {
  # pdf() cannot draw non-ASCII symbols such as a less-than-or-equal sign;
  # it warns on some and errors on others, so the labels must stay ASCII
  file <- tempfile(fileext = ".pdf")
  on.exit(unlink(file))
  fit <- fits$mia$fit
  for (type in types) {
    p <- ggfigs(fit, type, data = pima_diabetes,
                newdata = pima_diabetes[1, , drop = FALSE])
    expect_no_warning(ggplot2::ggsave(file, p, width = 9, height = 6))
  }
})

test_that("autoplot() returns the same static ggplot", {
  fit <- fits$regression$fit
  p <- ggplot2::autoplot(fit, type = "rules", data = mtcars)
  expect_renders(p)
  expect_identical(attr(p, "ggfigs_size"),
                   attr(ggfigs(fit, "rules", data = mtcars), "ggfigs_size"))
})

test_that("interactive = TRUE returns a girafe widget", {
  skip_if_not_installed("ggiraph")
  for (case in c("regression", "mia")) {
    fit <- fits[[case]]$fit
    d <- fits[[case]]$data
    for (type in types) {
      w <- ggfigs(fit, type, data = d, newdata = d[1, , drop = FALSE],
                  interactive = TRUE)
      expect_s3_class(w, "girafe")
    }
  }
})

test_that("the waterfall adds up to the model's prediction", {
  for (case in c("regression", "mia")) {
    fit <- fits[[case]]$fit
    d <- fits[[case]]$data
    p <- ggfigs(fit, "waterfall", newdata = d[3, , drop = FALSE])
    total <- p$data$delta[p$data$kind == "total"]
    raw <- fit$intercept + predict_trees(fit$trees, d[3, , drop = FALSE])
    expect_equal(total, raw)
  }
})

test_that("rules lays a chain tree on one row and branches below otherwise", {
  # with two splits in one tree the second split leaves a leaf beside it, so
  # the tree is a chain: every split has a leaf child
  chain <- figs(mpg ~ wt + hp, data = mtcars, max_splits = 2, max_trees = 1)
  p <- ggfigs(chain, "rules")
  boxes <- p$layers[[3]]$data
  expect_equal(nrow(boxes), 2)
  expect_length(unique(boxes$y), 1)

  # one box per split and one value per leaf, in every case
  for (case in names(fits)) {
    fit <- fits[[case]]$fit
    p <- ggfigs(fit, "rules")
    n_leaves <- sum(vapply(fit$trees, function(tr)
      sum(vapply(tr, function(nd) nd$is_leaf, logical(1))), integer(1)))
    expect_equal(nrow(p$layers[[3]]$data), fit$total_splits)
    expect_equal(nrow(p$layers[[8]]$data), n_leaves)
  }

  ir <- fits$factor_predictor
  p <- ggfigs(ir$fit, "rules")
  expect_gt(length(unique(p$layers[[3]]$data$y)), length(ir$fit$trees))
})

test_that("rules shows outcome rates only when given the data", {
  fit <- fits$mia$fit
  no_data <- ggfigs(fit, "rules")$layers[[3]]$data$stats
  expect_true(all(grepl("^n = \\d+$", no_data)))
  with_data <- ggfigs(fit, "rules", data = pima_diabetes)$layers[[3]]$data$stats
  expect_true(all(grepl("^\\d+/\\d+ \\(\\d+\\.\\d%\\) yes$", with_data)))
  expect_identical(with_data[1], "268/768 (34.9%) yes")

  reg <- ggfigs(fits$regression$fit, "rules", data = mtcars)$layers[[3]]$data$stats
  expect_true(all(grepl("^n = \\d+, mean ", reg)))

  size <- attr(ggfigs(fit, "rules"), "ggfigs_size")
  expect_named(size, c("width", "height"))
  expect_true(all(size > 0))
})

test_that("cuts names the splits it cannot draw", {
  p <- ggfigs(fits$factor_predictor$fit, "cuts", data = fits$factor_predictor$data)
  expect_match(p$labels$caption, "size in {small}", fixed = TRUE)
})

test_that("titles name the view and axes name the response", {
  reg <- fits$regression
  titles <- vapply(types, function(type) {
    ggfigs(reg$fit, type, data = reg$data, newdata = reg$data[1, ])$labels$title
  }, character(1))
  expect_identical(unname(titles), c("FIGS trees", "FIGS rules",
    "Prediction breakdown", "Split points", "Partial dependence"))
  expect_identical(ggfigs(reg$fit)$labels$subtitle, "3 trees, 6 splits")
  expect_identical(ggfigs(reg$fit, "cuts", data = mtcars)$labels$y, "mpg")
  expect_identical(ggfigs(reg$fit, "profile", data = mtcars)$labels$y,
                   "Average predicted mpg")

  cl <- fits$formula_outcome$fit
  expect_match(ggfigs(cl)$labels$subtitle, "leaf values are P(factor(am) = 1)",
               fixed = TRUE)
  expect_identical(ggfigs(cl, "waterfall", newdata = mtcars[1, ])$labels$y,
                   "P(factor(am) = 1)")
})

test_that("ggfigs() rejects bad input with clear errors", {
  fit <- fits$regression$fit
  expect_error(ggfigs(lm(mpg ~ wt, mtcars)), "`figsr_fit` object")
  expect_error(ggfigs(fit, "cuts"), "needs `data =`")
  expect_error(ggfigs(fit, "profile"), "needs `data =`")
  expect_error(ggfigs(fit, "cuts", data = mtcars[1:10, ]), "has 10 rows")
  expect_error(ggfigs(fit, "rules", data = mtcars[1:10, ]), "has 10 rows")
  expect_error(ggfigs(fit, "waterfall"), "needs `newdata =`")
  expect_error(ggfigs(fit, "waterfall", newdata = mtcars[1:2, ]), "exactly one row")
  expect_error(ggfigs(fit, "tree", tree_idx = 99), "`tree_idx`")
  expect_error(ggfigs(fit, interactive = NA), "TRUE or FALSE")
  expect_error(ggfigs(fit, "profile", data = mtcars, features = "nope"),
               "no predictor to profile")

  empty <- figs(mpg ~ wt, data = mtcars, max_splits = 0)
  for (type in c("tree", "rules")) {
    expect_error(ggfigs(empty, type), "no trees")
  }
  expect_error(ggfigs(empty, "cuts", data = mtcars), "no splits")
})
