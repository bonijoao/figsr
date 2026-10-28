# Predict Method for `figsr_fit` Models

Predict Method for `figsr_fit` Models

## Usage

``` r
# S3 method for class 'figsr_fit'
predict(object, new_data, type = NULL, ...)
```

## Arguments

- object:

  A fitted `figsr_fit` object.

- new_data:

  A data frame of new predictor observations.

- type:

  Character. Either `"numeric"`, `"class"`, or `"prob"`. Default depends
  on model mode.

- ...:

  Additional arguments.

## Value

A `tibble` with predictions in standardized `tidymodels` format.

## Examples

``` r
set.seed(42)
df <- data.frame(x1 = rnorm(50), y = rnorm(50))
fit <- figs(y ~ x1, data = df)
predict(fit, new_data = df)
#> # A tibble: 50 × 1
#>      .pred
#>      <dbl>
#>  1 -0.581 
#>  2 -0.132 
#>  3  1.40  
#>  4  0.508 
#>  5  0.302 
#>  6 -0.0829
#>  7 -0.581 
#>  8  0.304 
#>  9 -0.581 
#> 10  0.304 
#> # ℹ 40 more rows
```
