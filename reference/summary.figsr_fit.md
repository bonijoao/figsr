# Summary Method for `figsr_fit` Models

`summary.figsr_fit()` prints human-readable decision rules for each tree
in the sum.

## Usage

``` r
# S3 method for class 'figsr_fit'
summary(object, ...)
```

## Arguments

- object:

  A `figsr_fit` object.

- ...:

  Additional arguments, currently ignored.

## Value

`object`, invisibly. Called for the side effect of printing the IF-THEN
decision rules of each tree to the console.

## Examples

``` r
set.seed(42)
df <- data.frame(x1 = rnorm(60), x2 = rnorm(60))
df$y <- 2 * (df$x1 > 0) + rnorm(60, sd = 0.2)
summary(figs(y ~ x1 + x2, data = df, max_splits = 3))
#> ========================================================
#>   FIGS Model Summary: Tree Sum Decision Rules
#> ========================================================
#> 
#> --- Tree 1 ---
#>   |-- IF x1 <= -0.005
#>   |   |-- IF x2 <= 0.795
#>   |   |   `-- Leaf Value: -0.0075
#>   |   `-- IF x2 >  0.795
#>   |       `-- Leaf Value: -0.1515
#>   `-- IF x1 >  -0.005
#>       |-- IF x1 <= 1.346
#>       |   `-- Leaf Value: +2.0274
#>       `-- IF x1 >  1.346
#>           `-- Leaf Value: +1.8420
#> 
```
