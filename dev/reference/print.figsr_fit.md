# Print Method for `figsr_fit` Models

Print Method for `figsr_fit` Models

## Usage

``` r
# S3 method for class 'figsr_fit'
print(x, ...)
```

## Arguments

- x:

  A `figsr_fit` object.

- ...:

  Additional arguments, currently ignored.

## Value

`x`, invisibly. Called for the side effect of printing a summary of the
fitted tree sum to the console.

## Examples

``` r
set.seed(42)
df <- data.frame(x1 = rnorm(60), x2 = rnorm(60))
df$y <- 2 * (df$x1 > 0) + rnorm(60, sd = 0.2)
print(figs(y ~ x1 + x2, data = df, max_splits = 3))
#> ========================================================
#>   FIGS: Fast Interpretable Greedy-Tree Sums Model
#> ========================================================
#> Mode              : regression
#> Total Trees       : 1
#> Total Splits      : 3 / 3 (max_splits)
#> Predictors        : x1, x2
#> Used in Splits    : x1, x2
#> Missing values    : omit
#> ========================================================
#> 
#> Use `summary(fit)` to display detailed decision rules.
#> Use `plot(fit)` to visualize decision tree structures.
```
