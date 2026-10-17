test_that("split_gains() equals the SSE reduction of the partition", {
  res <- c(1, 2, 3, 10, 11, 12)
  ss_total <- sum((res - mean(res))^2)
  left <- c(TRUE, TRUE, TRUE, FALSE, FALSE, FALSE)

  expected <- ss_total - (sum((res[left] - mean(res[left]))^2) +
                          sum((res[!left] - mean(res[!left]))^2))

  e <- res - mean(res)
  gain <- figsr:::split_gains(sum(e[left]), sum(left), sum(e), length(e), min_n = 1)
  expect_equal(gain, expected)
})

test_that("split_gains() scores every cutpoint of a sorted node at once", {
  set.seed(11)
  res <- rnorm(40)
  e <- res - mean(res)
  n_left <- 1:39
  gains <- figsr:::split_gains(cumsum(e)[n_left], n_left, sum(e), 40, min_n = 1)

  expected <- vapply(n_left, function(k) {
    left <- seq_len(40) <= k
    sum(e^2) - sum((res[left] - mean(res[left]))^2) -
      sum((res[!left] - mean(res[!left]))^2)
  }, numeric(1))
  expect_equal(gains, expected)
})

test_that("split_gains() rules out a side smaller than min_n", {
  res <- c(1, 2, 3, 10, 11, 12)
  e <- res - mean(res)
  n_left <- c(1, 3, 5)
  gains <- figsr:::split_gains(cumsum(e)[n_left], n_left, sum(e), 6, min_n = 2)

  expect_identical(gains[c(1, 3)], c(-Inf, -Inf))
  expect_type(gains[2], "double")
  expect_gt(gains[2], 0)
})

test_that("quantile7_sorted() matches stats::quantile() exactly", {
  set.seed(12)
  probs <- seq(0.05, 0.95, length.out = 30)
  for (i in 1:200) {
    xs <- sort(round(rnorm(sample(31:500, 1)), sample(0:4, 1)))
    expect_identical(figsr:::quantile7_sorted(xs, probs),
                     stats::quantile(xs, probs, names = FALSE))
  }
})
