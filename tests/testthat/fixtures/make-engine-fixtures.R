# Regenerates engine-0.2.0.rds: fits produced by the figsr 0.2.0 split search
# (commit 75fb251), which test-engine-regression.R holds every later engine to.
# Run from the package root with that version loaded:
#   Rscript tests/testthat/fixtures/make-engine-fixtures.R

pkgload::load_all(".", quiet = TRUE)

simulate <- function(n, p, seed, integer_x = FALSE) {
  set.seed(seed)
  X <- if (integer_x) {
    as.data.frame(matrix(sample(0:30, n * p, replace = TRUE), n, p))
  } else {
    as.data.frame(matrix(rnorm(n * p), n, p))
  }
  names(X) <- paste0("x", seq_len(p))
  z <- scale(as.matrix(X))
  z <- cbind(z, matrix(0, n, max(0, 5 - p)))
  X$y <- 3 * (z[, 1] > 0) + 2 * (z[, 2] > 0.5) - 1.5 * (z[, 3] < -0.2) +
    z[, 4] * (z[, 5] > 0) + rnorm(n, sd = 0.3)
  X
}

mixed <- simulate(500, 6, seed = 4)
for (j in c(2, 4, 6)) {
  k <- 3 + (j %% 4)
  mixed[[j]] <- factor(cut(mixed[[j]], k, labels = FALSE), labels = letters[1:k])
}
mixed_na <- mixed
mixed_na$x1[sample(500, 50)] <- NA
mixed_na$x2[sample(500, 50)] <- NA

chars <- simulate(400, 4, seed = 6)
chars$x2 <- sample(c("b", "a", "c"), 400, replace = TRUE)
chars$x3 <- factor(sample(letters[1:12], 400, replace = TRUE))
chars$y <- chars$y + 2 * (chars$x2 == "a")

binary <- simulate(500, 5, seed = 7)
binary$y <- factor(ifelse(binary$y > 1, "yes", "no"))

# The same partitions offered by two predictors: a mirror image, and a factor
# copied with its levels reordered. 0.2.0 reports the first predictor.
mirrored <- function(seed) {
  set.seed(seed)
  d <- data.frame(x1 = rnorm(300), x3 = rnorm(300))
  d$y <- 2 * (d$x1 > 0.3) + d$x3 + rnorm(300, sd = 0.5)
  d$x2 <- -d$x1
  d[c("x1", "x2", "x3", "y")]
}
relevelled <- function(seed) {
  set.seed(seed)
  g <- factor(sample(letters[1:4], 300, replace = TRUE))
  d <- data.frame(g1 = g, g2 = factor(as.character(g), levels = c("d", "c", "b", "a")),
                  x3 = rnorm(300))
  d$y <- (g %in% c("a", "c")) + d$x3 + rnorm(300, sd = 0.5)
  d
}

load("data/pima_diabetes.rda")

scenarios <- list(
  continuous = list(formula = y ~ ., data = simulate(400, 5, seed = 1),
                    args = list(max_splits = 12)),
  min_n_1 = list(formula = y ~ ., data = simulate(200, 4, seed = 2),
                 args = list(max_splits = 15, min_n = 1)),
  integer = list(formula = y ~ ., data = simulate(400, 5, seed = 3, integer_x = TRUE),
                 args = list(max_splits = 12)),
  max_trees = list(formula = y ~ ., data = simulate(400, 5, seed = 5),
                   args = list(max_splits = 12, max_trees = 2)),
  factors_omit = list(formula = y ~ ., data = mixed, args = list(max_splits = 12)),
  factors_mia = list(formula = y ~ ., data = mixed_na,
                     args = list(max_splits = 15, na_method = "mia")),
  characters = list(formula = y ~ ., data = chars, args = list(max_splits = 10)),
  classification = list(formula = y ~ ., data = binary, args = list(max_splits = 10)),
  pima_mia = list(formula = Outcome ~ ., data = pima_diabetes,
                  args = list(max_splits = 12, na_method = "mia")),
  mirrored_7 = list(formula = y ~ ., data = mirrored(7), args = list(max_splits = 12, min_n = 2)),
  mirrored_10 = list(formula = y ~ ., data = mirrored(10), args = list(max_splits = 12, min_n = 2)),
  relevelled_1 = list(formula = y ~ ., data = relevelled(1), args = list(max_splits = 12, min_n = 2)),
  relevelled_2 = list(formula = y ~ ., data = relevelled(2), args = list(max_splits = 12, min_n = 2)),
  relevelled_3 = list(formula = y ~ ., data = relevelled(3), args = list(max_splits = 12, min_n = 2))
)

for (nm in names(scenarios)) {
  s <- scenarios[[nm]]
  fit <- do.call(figs, c(list(formula = s$formula, data = s$data), s$args))
  scenarios[[nm]]$expected <- fit[c("trees", "intercept", "total_splits", "fitted_values")]
}

saveRDS(scenarios, "tests/testthat/fixtures/engine-0.2.0.rds", version = 3)
