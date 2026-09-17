test_that("split_gain() equals the SSE reduction of the partition", {
  res <- c(1, 2, 3, 10, 11, 12)
  ss_total <- sum((res - mean(res))^2)
  left <- c(TRUE, TRUE, TRUE, FALSE, FALSE, FALSE)

  expected <- ss_total - (sum((res[left] - mean(res[left]))^2) +
                          sum((res[!left] - mean(res[!left]))^2))

  expect_equal(figsr:::split_gain(res, ss_total, left, min_n = 1), expected)
})

test_that("split_gain() returns NULL when a side is smaller than min_n", {
  res <- c(1, 2, 3, 10, 11, 12)
  ss_total <- sum((res - mean(res))^2)

  expect_null(figsr:::split_gain(res, ss_total, c(TRUE, rep(FALSE, 5)), min_n = 2))
  expect_null(figsr:::split_gain(res, ss_total, c(rep(TRUE, 5), FALSE), min_n = 2))
  expect_type(figsr:::split_gain(res, ss_total, c(rep(TRUE, 3), rep(FALSE, 3)), min_n = 3), "double")
})
