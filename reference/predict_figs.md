# Internal / Parsnip Predict Bridge Function for `figsr_fit`

Internal / Parsnip Predict Bridge Function for `figsr_fit`

## Usage

``` r
predict_figs(object, new_data, type = "numeric", ...)
```

## Arguments

- object:

  A fitted `figsr_fit` object.

- new_data:

  A data frame of new predictor observations.

- type:

  Character. `"numeric"`, `"class"`, or `"prob"`.

- ...:

  Additional arguments.

## Value

A `tibble` of predictions.

## Examples

``` r
set.seed(42)
df <- data.frame(x1 = rnorm(60))
df$y <- 2 * (df$x1 > 0) + rnorm(60, sd = 0.2)
fit <- figs(y ~ x1, data = df, max_splits = 3)
predict_figs(fit, new_data = df, type = "numeric")
#> # A tibble: 60 × 1
#>    .pred
#>    <dbl>
#>  1 1.94 
#>  2 0.117
#>  3 2.08 
#>  4 2.08 
#>  5 2.08 
#>  6 0.117
#>  7 1.94 
#>  8 0.117
#>  9 1.94 
#> 10 0.117
#> # ℹ 50 more rows
```
