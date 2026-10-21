# Predict Method for `bagging_figs_fit` Models

Predict Method for `bagging_figs_fit` Models

## Usage

``` r
# S3 method for class 'bagging_figs_fit'
predict(object, new_data, type = NULL, ...)
```

## Arguments

- object:

  A fitted `bagging_figs_fit` object.

- new_data:

  A data frame of predictor values.

- type:

  Character. For classification, either `"class"` (the default) or
  `"prob"`; ignored for regression, which always returns `.pred`.

- ...:

  Additional arguments.

## Value

A `tibble` containing averaged ensemble predictions.

## Examples

``` r
set.seed(42)
df <- data.frame(x1 = rnorm(60), x2 = rnorm(60))
df$y <- 2 * (df$x1 > 0) + rnorm(60, sd = 0.2)
bag_fit <- bagging_figs(y ~ x1 + x2, data = df, n_estimators = 3)
predict(bag_fit, new_data = df)
#> # A tibble: 60 × 1
#>       .pred
#>       <dbl>
#>  1  1.88   
#>  2 -0.0680 
#>  3  2.05   
#>  4  2.02   
#>  5  2.03   
#>  6 -0.0417 
#>  7  1.86   
#>  8 -0.0417 
#>  9  1.82   
#> 10 -0.00486
#> # ℹ 50 more rows
```
