# The split search is an optimization target, but the model it returns is not:
# every fit must reproduce, split for split, what figsr 0.2.0 produced on the
# same data (see fixtures/make-engine-fixtures.R). Tree structure, cutpoints,
# level subsets, missing-value routing and sample indices must match exactly;
# leaf values, gains and fitted values may differ only by rounding.

scenarios <- readRDS(test_path("fixtures", "engine-0.2.0.rds"))

exact_fields <- c("id", "is_leaf", "feature", "is_factor", "split_val",
                  "left_child", "right_child", "sample_indices", "na_dir",
                  "split_on_missing")

for (nm in names(scenarios)) {
  test_that(paste("the fit matches figsr 0.2.0:", nm), {
    s <- scenarios[[nm]]
    fit <- do.call(figs, c(list(formula = s$formula, data = s$data), s$args))
    expected <- s$expected

    expect_identical(fit$total_splits, expected$total_splits)
    expect_identical(fit$intercept, expected$intercept)
    expect_length(fit$trees, length(expected$trees))
    for (t in seq_along(expected$trees)) {
      expect_length(fit$trees[[t]], length(expected$trees[[t]]))
      for (k in seq_along(expected$trees[[t]])) {
        got <- fit$trees[[t]][[k]]
        want <- expected$trees[[t]][[k]]
        expect_identical(got[exact_fields], want[exact_fields])
        expect_equal(got$value, want$value, tolerance = 1e-8)
        expect_equal(got$gain, want$gain, tolerance = 1e-8)
      }
    }
    expect_equal(fit$fitted_values, expected$fitted_values, tolerance = 1e-8)
  })
}
