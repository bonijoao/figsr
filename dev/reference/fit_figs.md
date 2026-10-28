# Fitting Bridge for the Parsnip Interface

`fit_figs()` is the function `parsnip` calls when fitting a
[`figs_tree()`](https://bonijoao.github.io/figsr/dev/reference/figs_tree.md)
specification with the `"figsr"` engine. It accepts either the formula
interface or the `x`/`y` interface and forwards to
[`figs()`](https://bonijoao.github.io/figsr/dev/reference/figs.md).
Users normally call
[`figs()`](https://bonijoao.github.io/figsr/dev/reference/figs.md) or
[`fit()`](https://generics.r-lib.org/reference/fit.html) instead.

## Usage

``` r
fit_figs(
  formula = NULL,
  data = NULL,
  x = NULL,
  y = NULL,
  max_splits = 10,
  max_trees = NULL,
  min_n = 5,
  mode = "regression",
  na_method = c("omit", "mia"),
  ...
)
```

## Arguments

- formula:

  A formula specifying outcome and predictors.

- data:

  A data frame containing the training data.

- x:

  A data frame or matrix of predictors.

- y:

  An outcome vector.

- max_splits:

  Integer. Maximum total number of splits across all trees.

- max_trees:

  Integer. Maximum number of trees in the sum.

- min_n:

  Integer. Minimum number of observations in a node to split.

- mode:

  Character. Either `"regression"` or `"classification"`; classification
  supports two-class outcomes only.

- na_method:

  Character. `"omit"` or `"mia"`; see
  [`figs()`](https://bonijoao.github.io/figsr/dev/reference/figs.md).
  Set it as an engine argument:
  `set_engine("figsr", na_method = "mia")`.

- ...:

  Additional arguments passed to
  [`figs()`](https://bonijoao.github.io/figsr/dev/reference/figs.md).

## Value

An object of class `figsr_fit`.

## Examples

``` r
set.seed(42)
df <- data.frame(x1 = rnorm(60), x2 = rnorm(60))
df$y <- 2 * (df$x1 > 0) + rnorm(60, sd = 0.2)
fit_figs(x = df[, c("x1", "x2")], y = df$y, max_splits = 3)
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
