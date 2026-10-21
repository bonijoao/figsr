# Calculate Variable Importance for a `figsr_fit` Model

`figsr_importance()` computes the total reduction in residual impurity
(Sum of Squares gain) attributable to each predictor feature across all
trees in the fitted FIGS model.

## Usage

``` r
figsr_importance(object, relative = TRUE)
```

## Arguments

- object:

  A fitted `figsr_fit` model object.

- relative:

  Logical. If `TRUE` (default), the `importance` column is rescaled to
  percentages of the total gain; otherwise it repeats the raw gain.

## Value

A `tibble` with one row per predictor and columns `feature`, `gain` (raw
sum-of-squares reduction) and `importance`, sorted by decreasing
importance.

## Details

Each split node stores the reduction in residual sum of squares it
achieved at the moment it was chosen. Importance for a feature is the
sum of those gains over every split made on that feature, across all
trees in the sum. Features never selected receive a gain of zero.

When the model was fitted with `na_method = "mia"`, a split on whether a
predictor is missing is reported on its own row, named
`missing(<predictor>)`, because such a split never consults the
predictor's value. A split that merely sends missing values to one side
is credited to the predictor.

## Examples

``` r
set.seed(42)
df <- data.frame(x1 = rnorm(50), x2 = rnorm(50))
df$y <- 2 * (df$x1 > 0) + rnorm(50, sd = 0.2)
fit <- figs(y ~ x1 + x2, data = df, max_splits = 3)
figsr_importance(fit)
#> # A tibble: 2 × 3
#>   feature  gain importance
#>   <chr>   <dbl>      <dbl>
#> 1 x1       52.2        100
#> 2 x2        0            0
```
